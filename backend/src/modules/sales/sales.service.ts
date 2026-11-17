import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { DataSource } from 'typeorm';
import Decimal from 'decimal.js';

@Injectable()
export class SalesService {
  constructor(private readonly dataSource: DataSource) {}

  async getSales(query: any) {
    const limit = parseInt(query.limit || '20', 10);
    const offset = (parseInt(query.page || '1', 10) - 1) * limit;
    const conditions: string[] = ['1=1'];
    const values: any[] = [];
    let idx = 1;

    if (query.status) {
      conditions.push(`s.status = $${idx++}`);
      values.push(query.status);
    }
    if (query.paymentStatus) {
      conditions.push(`s.payment_status = $${idx++}`);
      values.push(query.paymentStatus);
    }
    if (query.customerId) {
      conditions.push(`s.customer_id = $${idx++}`);
      values.push(query.customerId);
    }

    values.push(limit);
    values.push(offset);

    const data = await this.dataSource.query(
      `SELECT s.*, 
        c.name AS customer_name,
        c.phone AS customer_phone,
        u.full_name AS created_by_name,
        (SELECT COUNT(*) FROM sale_items si WHERE si.sale_id = s.id) AS item_count
       FROM sales s
       LEFT JOIN customers c ON s.customer_id = c.id
       LEFT JOIN users u ON s.created_by = u.id
       WHERE ${conditions.join(' AND ')}
       ORDER BY s.created_at DESC
       LIMIT $${idx++} OFFSET $${idx++}`,
      values,
    );

    const [countRes] = await this.dataSource.query(
      `SELECT COUNT(*) as total FROM sales s WHERE ${conditions.join(' AND ')}`,
      values.slice(0, values.length - 2),
    );

    return {
      data,
      meta: {
        total: parseInt(countRes?.total || '0', 10),
        page: parseInt(query.page || '1', 10),
        limit,
      },
    };
  }

  async getSaleById(id: string) {
    const [sale] = await this.dataSource.query(
      `SELECT s.*, c.name AS customer_name, c.phone AS customer_phone, c.inn AS customer_inn, u.full_name AS created_by_name
       FROM sales s
       LEFT JOIN customers c ON s.customer_id = c.id
       LEFT JOIN users u ON s.created_by = u.id
       WHERE s.id = $1`,
      [id],
    );
    if (!sale) throw new NotFoundException('Продажа не найдена');

    const items = await this.dataSource.query(
      `SELECT si.*, p.name AS product_name, p.sku AS product_sku, p.unit
       FROM sale_items si
       JOIN products p ON si.product_id = p.id
       WHERE si.sale_id = $1`,
      [id],
    );

    const payments = await this.dataSource.query(
      `SELECT p.*, a.name AS account_name
       FROM payments p
       LEFT JOIN accounts a ON p.account_id = a.id
       WHERE p.sale_id = $1
       ORDER BY p.payment_date DESC`,
      [id],
    );

    return { ...sale, items, payments };
  }

  async createSale(
    dto: {
      customerId?: string;
      warehouseId?: string;
      discount?: number | string;
      items: Array<{ productId: string; quantity: number | string; unitPrice: number | string; discount?: number | string }>;
      payment?: { accountId: string; amount: number | string; paymentMethod?: string };
    },
    userId?: string,
  ) {
    const queryRunner = this.dataSource.createQueryRunner();
    await queryRunner.connect();
    await queryRunner.startTransaction();

    try {
      let warehouseId = dto.warehouseId;
      if (!warehouseId) {
        const [w] = await queryRunner.query(`SELECT id FROM warehouses LIMIT 1`);
        warehouseId = w?.id;
      }

      // 1. Validate stock availability for all products
      for (const item of dto.items) {
        const itemQty = new Decimal(item.quantity);
        if (itemQty.lte(0)) {
          throw new BadRequestException('Количество товара должно быть больше 0');
        }

        const [inv] = await queryRunner.query(
          `SELECT i.quantity, p.name FROM inventory i
           JOIN products p ON i.product_id = p.id
           WHERE i.product_id = $1 AND i.warehouse_id = $2 FOR UPDATE`,
          [item.productId, warehouseId],
        );

        const available = new Decimal(inv?.quantity || 0);
        if (available.lt(itemQty)) {
          throw new BadRequestException(`Недостаточно товара на складе: ${inv?.name || item.productId}. Доступно: ${available}, запрошено: ${itemQty}`);
        }
      }

      // 2. Calculate totals and cost price
      let subtotalDec = new Decimal(0);
      let totalCostDec = new Decimal(0);

      const itemsWithCost: any[] = [];
      for (const item of dto.items) {
        const qty = new Decimal(item.quantity);
        const price = new Decimal(item.unitPrice);
        const itemDiscount = item.discount ? new Decimal(item.discount) : new Decimal(0);
        const lineTotal = qty.times(price).minus(itemDiscount);
        subtotalDec = subtotalDec.plus(lineTotal);

        const [inv] = await queryRunner.query(
          `SELECT average_cost FROM inventory WHERE product_id = $1 AND warehouse_id = $2`,
          [item.productId, warehouseId],
        );
        const costPrice = new Decimal(inv?.average_cost || 0);
        totalCostDec = totalCostDec.plus(costPrice.times(qty));

        itemsWithCost.push({
          ...item,
          qty,
          price,
          itemDiscount,
          lineTotal,
          costPrice,
        });
      }

      const overallDiscount = dto.discount ? new Decimal(dto.discount) : new Decimal(0);
      const grandTotalDec = subtotalDec.minus(overallDiscount);

      // 3. Payment calculations
      const paymentAmount = dto.payment ? new Decimal(dto.payment.amount) : new Decimal(0);
      let paymentStatus = 'UNPAID';
      if (paymentAmount.gte(grandTotalDec)) {
        paymentStatus = 'PAID';
      } else if (paymentAmount.gt(0)) {
        paymentStatus = 'PARTIAL';
      }

      const saleNumber = `INV-${Date.now().toString().slice(-6)}`;

      // 4. Create sale record
      const [sale] = await queryRunner.query(
        `INSERT INTO sales (sale_number, customer_id, warehouse_id, status, payment_status, subtotal, discount, grand_total, paid_amount, created_by)
         VALUES ($1, $2, $3, 'COMPLETED', $4, $5, $6, $7, $8, $9) RETURNING *`,
        [
          saleNumber,
          dto.customerId || null,
          warehouseId,
          paymentStatus,
          subtotalDec.toFixed(2),
          overallDiscount.toFixed(2),
          grandTotalDec.toFixed(2),
          paymentAmount.toFixed(2),
          userId || null,
        ],
      );

      // 5. Create sale items and decrement inventory
      for (const item of itemsWithCost) {
        await queryRunner.query(
          `INSERT INTO sale_items (sale_id, product_id, quantity, unit_price, cost_price, discount, total_amount)
           VALUES ($1, $2, $3, $4, $5, $6, $7)`,
          [
            sale.id,
            item.productId,
            item.qty.toFixed(2),
            item.price.toFixed(2),
            item.costPrice.toFixed(2),
            item.itemDiscount.toFixed(2),
            item.lineTotal.toFixed(2),
          ],
        );

        // Decrement stock
        await queryRunner.query(
          `UPDATE inventory SET quantity = quantity - $1, last_updated_at = NOW()
           WHERE product_id = $2 AND warehouse_id = $3`,
          [item.qty.toFixed(2), item.productId, warehouseId],
        );

        // Fetch balance after
        const [updatedInv] = await queryRunner.query(
          `SELECT quantity FROM inventory WHERE product_id = $1 AND warehouse_id = $2`,
          [item.productId, warehouseId],
        );

        // Record stock movement (OUTGOING)
        await queryRunner.query(
          `INSERT INTO stock_movements (product_id, warehouse_id, type, quantity, balance_after, reference_type, reference_id, reason, created_by)
           VALUES ($1, $2, 'OUTGOING', $3, $4, 'SALE', $5, $6, $7)`,
          [
            item.productId,
            warehouseId,
            item.qty.toFixed(2),
            updatedInv.quantity,
            sale.id,
            `Расход по продаже №${saleNumber}`,
            userId || null,
          ],
        );
      }

      // 6. Handle payment if provided
      if (dto.payment && paymentAmount.gt(0)) {
        await queryRunner.query(
          `INSERT INTO payments (type, account_id, customer_id, sale_id, amount, payment_method, notes, created_by)
           VALUES ('INCOMING', $1, $2, $3, $4, $5, $6, $7)`,
          [
            dto.payment.accountId,
            dto.customerId || null,
            sale.id,
            paymentAmount.toFixed(2),
            dto.payment.paymentMethod || 'CASH',
            `Оплата продажи №${saleNumber}`,
            userId || null,
          ],
        );

        // Create finance transaction (INCOME)
        await queryRunner.query(
          `INSERT INTO transactions (account_id, type, amount, description, reference_type, reference_id, created_by)
           VALUES ($1, 'INCOME', $2, $3, 'SALE', $4, $5)`,
          [
            dto.payment.accountId,
            paymentAmount.toFixed(2),
            `Поступление по продаже №${saleNumber}`,
            sale.id,
            userId || null,
          ],
        );

        // Atomically update account balance
        await queryRunner.query(
          `UPDATE accounts SET balance = balance + $1 WHERE id = $2`,
          [paymentAmount.toFixed(2), dto.payment.accountId],
        );
      }

      // Update customer balance if debt remains
      const remainingDebt = grandTotalDec.minus(paymentAmount);
      if (dto.customerId && remainingDebt.gt(0)) {
        await queryRunner.query(
          `UPDATE customers SET balance = balance + $1 WHERE id = $2`,
          [remainingDebt.toFixed(2), dto.customerId],
        );
      }

      // Audit log
      const grossProfit = grandTotalDec.minus(totalCostDec);
      await queryRunner.query(
        `INSERT INTO audit_logs (user_id, action, entity_name, entity_id, new_values)
         VALUES ($1, 'CREATE_SALE', 'SALE', $2, $3)`,
        [
          userId || null,
          sale.id,
          JSON.stringify({
            saleNumber,
            grandTotal: grandTotalDec.toNumber(),
            grossProfit: grossProfit.toNumber(),
            paidAmount: paymentAmount.toNumber(),
          }),
        ],
      );

      await queryRunner.commitTransaction();
      return { ...sale, grossProfit: grossProfit.toNumber() };
    } catch (err) {
      await queryRunner.rollbackTransaction();
      throw err;
    } finally {
      await queryRunner.release();
    }
  }

  async processPayment(
    saleId: string,
    dto: { accountId: string; amount: number | string; paymentMethod?: string; notes?: string },
    userId?: string,
  ) {
    const queryRunner = this.dataSource.createQueryRunner();
    await queryRunner.connect();
    await queryRunner.startTransaction();

    try {
      const [sale] = await queryRunner.query(`SELECT * FROM sales WHERE id = $1 FOR UPDATE`, [saleId]);
      if (!sale) throw new NotFoundException('Продажа не найдена');

      const paymentDec = new Decimal(dto.amount);
      if (paymentDec.lte(0)) throw new BadRequestException('Сумма платежа должна быть больше 0');

      const currentPaid = new Decimal(sale.paid_amount);
      const grandTotal = new Decimal(sale.grand_total);
      const newPaid = currentPaid.plus(paymentDec);

      let newStatus = 'PARTIAL';
      if (newPaid.gte(grandTotal)) {
        newStatus = 'PAID';
      }

      // Insert payment
      await queryRunner.query(
        `INSERT INTO payments (type, account_id, customer_id, sale_id, amount, payment_method, notes, created_by)
         VALUES ('INCOMING', $1, $2, $3, $4, $5, $6, $7)`,
        [
          dto.accountId,
          sale.customer_id,
          saleId,
          paymentDec.toFixed(2),
          dto.paymentMethod || 'CASH',
          dto.notes || `Доплата по заказу №${sale.sale_number}`,
          userId || null,
        ],
      );

      // Create finance transaction
      await queryRunner.query(
        `INSERT INTO transactions (account_id, type, amount, description, reference_type, reference_id, created_by)
         VALUES ($1, 'INCOME', $2, $3, 'SALE', $4, $5)`,
        [
          dto.accountId,
          paymentDec.toFixed(2),
          `Доплата по заказу №${sale.sale_number}`,
          saleId,
          userId || null,
        ],
      );

      // Update account balance
      await queryRunner.query(
        `UPDATE accounts SET balance = balance + $1 WHERE id = $2`,
        [paymentDec.toFixed(2), dto.accountId],
      );

      // Update sale
      await queryRunner.query(
        `UPDATE sales SET paid_amount = $1, payment_status = $2, updated_at = NOW() WHERE id = $3`,
        [newPaid.toFixed(2), newStatus, saleId],
      );

      // Decrease customer debt
      if (sale.customer_id) {
        await queryRunner.query(
          `UPDATE customers SET balance = balance - $1 WHERE id = $2`,
          [paymentDec.toFixed(2), sale.customer_id],
        );
      }

      await queryRunner.commitTransaction();
      return { success: true, newPaidAmount: newPaid.toNumber(), paymentStatus: newStatus };
    } catch (err) {
      await queryRunner.rollbackTransaction();
      throw err;
    } finally {
      await queryRunner.release();
    }
  }

  async createReturn(
    saleId: string,
    dto: { items: Array<{ productId: string; quantity: number | string }>; reason?: string },
    userId?: string,
  ) {
    const queryRunner = this.dataSource.createQueryRunner();
    await queryRunner.connect();
    await queryRunner.startTransaction();

    try {
      const [sale] = await queryRunner.query(`SELECT * FROM sales WHERE id = $1 FOR UPDATE`, [saleId]);
      if (!sale) throw new NotFoundException('Продажа не найдена');

      const warehouseId = sale.warehouse_id;

      for (const item of dto.items) {
        const qty = new Decimal(item.quantity);

        // Return stock to inventory
        await queryRunner.query(
          `UPDATE inventory SET quantity = quantity + $1, last_updated_at = NOW()
           WHERE product_id = $2 AND warehouse_id = $3`,
          [qty.toFixed(2), item.productId, warehouseId],
        );

        const [inv] = await queryRunner.query(
          `SELECT quantity FROM inventory WHERE product_id = $1 AND warehouse_id = $2`,
          [item.productId, warehouseId],
        );

        // Stock movement INCOMING (RETURN)
        await queryRunner.query(
          `INSERT INTO stock_movements (product_id, warehouse_id, type, quantity, balance_after, reference_type, reference_id, reason, created_by)
           VALUES ($1, $2, 'INCOMING', $3, $4, 'SALE_RETURN', $5, $6, $7)`,
          [
            item.productId,
            warehouseId,
            qty.toFixed(2),
            inv.quantity,
            saleId,
            dto.reason || 'Возврат товара',
            userId || null,
          ],
        );
      }

      await queryRunner.query(
        `UPDATE sales SET status = 'RETURNED', updated_at = NOW() WHERE id = $1`,
        [saleId],
      );

      await queryRunner.commitTransaction();
      return { success: true, message: 'Возврат успешно оформлен' };
    } catch (err) {
      await queryRunner.rollbackTransaction();
      throw err;
    } finally {
      await queryRunner.release();
    }
  }
}
