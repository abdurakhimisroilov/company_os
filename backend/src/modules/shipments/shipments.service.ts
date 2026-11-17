import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { DataSource } from 'typeorm';
import Decimal from 'decimal.js';

@Injectable()
export class ShipmentsService {
  constructor(private readonly dataSource: DataSource) {}

  async getShipments(query: any) {
    const limit = parseInt(query.limit || '20', 10);
    const offset = (parseInt(query.page || '1', 10) - 1) * limit;
    const conditions: string[] = ['1=1'];
    const values: any[] = [];
    let idx = 1;

    if (query.status) {
      conditions.push(`s.status = $${idx++}`);
      values.push(query.status);
    }
    if (query.supplierId) {
      conditions.push(`s.supplier_id = $${idx++}`);
      values.push(query.supplierId);
    }

    values.push(limit);
    values.push(offset);

    const data = await this.dataSource.query(
      `SELECT s.*, 
        sup.name AS supplier_name,
        w.name AS warehouse_name,
        (SELECT COUNT(*) FROM incoming_shipment_items isi WHERE isi.shipment_id = s.id) AS item_count
       FROM incoming_shipments s
       LEFT JOIN suppliers sup ON s.supplier_id = sup.id
       LEFT JOIN warehouses w ON s.warehouse_id = w.id
       WHERE ${conditions.join(' AND ')}
       ORDER BY s.created_at DESC
       LIMIT $${idx++} OFFSET $${idx++}`,
      values,
    );

    const [countRes] = await this.dataSource.query(
      `SELECT COUNT(*) as total FROM incoming_shipments s WHERE ${conditions.join(' AND ')}`,
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

  async getShipmentById(id: string) {
    const [shipment] = await this.dataSource.query(
      `SELECT s.*, sup.name AS supplier_name, sup.phone AS supplier_phone, w.name AS warehouse_name
       FROM incoming_shipments s
       LEFT JOIN suppliers sup ON s.supplier_id = sup.id
       LEFT JOIN warehouses w ON s.warehouse_id = w.id
       WHERE s.id = $1`,
      [id],
    );
    if (!shipment) throw new NotFoundException('Поставка не найдена');

    const items = await this.dataSource.query(
      `SELECT isi.*, p.name AS product_name, p.sku AS product_sku, p.unit
       FROM incoming_shipment_items isi
       JOIN products p ON isi.product_id = p.id
       WHERE isi.shipment_id = $1`,
      [id],
    );

    const costs = await this.dataSource.query(
      `SELECT * FROM shipment_costs WHERE shipment_id = $1`,
      [id],
    );

    return { ...shipment, items, costs };
  }

  async createShipment(
    dto: {
      supplierId: string;
      warehouseId?: string;
      expectedDate?: string;
      notes?: string;
      items: Array<{ productId: string; quantity: number | string; purchasePrice: number | string }>;
      costs?: Array<{ name: string; amount: number | string }>;
    },
    userId?: string,
  ) {
    const queryRunner = this.dataSource.createQueryRunner();
    await queryRunner.connect();
    await queryRunner.startTransaction();

    try {
      const shipmentNumber = `SHP-${Date.now().toString().slice(-6)}`;

      let totalAmountDec = new Decimal(0);
      for (const item of dto.items) {
        const itemTotal = new Decimal(item.quantity).times(new Decimal(item.purchasePrice));
        totalAmountDec = totalAmountDec.plus(itemTotal);
      }

      let additionalCostsDec = new Decimal(0);
      if (dto.costs) {
        for (const cost of dto.costs) {
          additionalCostsDec = additionalCostsDec.plus(new Decimal(cost.amount));
        }
      }

      let warehouseId = dto.warehouseId;
      if (!warehouseId) {
        const [w] = await queryRunner.query(`SELECT id FROM warehouses LIMIT 1`);
        warehouseId = w?.id;
      }

      const [shipment] = await queryRunner.query(
        `INSERT INTO incoming_shipments (shipment_number, supplier_id, warehouse_id, status, expected_date, total_amount, additional_costs, notes, created_by)
         VALUES ($1, $2, $3, 'PENDING', $4, $5, $6, $7, $8) RETURNING *`,
        [
          shipmentNumber,
          dto.supplierId || null,
          warehouseId || null,
          dto.expectedDate || null,
          totalAmountDec.toFixed(2),
          additionalCostsDec.toFixed(2),
          dto.notes || null,
          userId || null,
        ],
      );

      for (const item of dto.items) {
        const itemTotal = new Decimal(item.quantity).times(new Decimal(item.purchasePrice));
        await queryRunner.query(
          `INSERT INTO incoming_shipment_items (shipment_id, product_id, quantity, purchase_price, total_amount)
           VALUES ($1, $2, $3, $4, $5)`,
          [
            shipment.id,
            item.productId,
            new Decimal(item.quantity).toFixed(2),
            new Decimal(item.purchasePrice).toFixed(2),
            itemTotal.toFixed(2),
          ],
        );
      }

      if (dto.costs && dto.costs.length > 0) {
        for (const cost of dto.costs) {
          await queryRunner.query(
            `INSERT INTO shipment_costs (shipment_id, name, amount) VALUES ($1, $2, $3)`,
            [shipment.id, cost.name, new Decimal(cost.amount).toFixed(2)],
          );
        }
      }

      // Audit log
      await queryRunner.query(
        `INSERT INTO audit_logs (user_id, action, entity_name, entity_id, new_values)
         VALUES ($1, 'CREATE', 'SHIPMENT', $2, $3)`,
        [userId || null, shipment.id, JSON.stringify(shipment)],
      );

      await queryRunner.commitTransaction();
      return shipment;
    } catch (err) {
      await queryRunner.rollbackTransaction();
      throw err;
    } finally {
      await queryRunner.release();
    }
  }

  async confirmReceipt(shipmentId: string, userId?: string) {
    const queryRunner = this.dataSource.createQueryRunner();
    await queryRunner.connect();
    await queryRunner.startTransaction();

    try {
      const [shipment] = await queryRunner.query(
        `SELECT * FROM incoming_shipments WHERE id = $1 FOR UPDATE`,
        [shipmentId],
      );
      if (!shipment) throw new NotFoundException('Поставка не найдена');
      if (shipment.status === 'RECEIVED') {
        throw new BadRequestException('Поставка уже оприходована');
      }

      const items = await queryRunner.query(
        `SELECT * FROM incoming_shipment_items WHERE shipment_id = $1`,
        [shipmentId],
      );

      let warehouseId = shipment.warehouse_id;
      if (!warehouseId) {
        const [w] = await queryRunner.query(`SELECT id FROM warehouses LIMIT 1`);
        warehouseId = w?.id;
      }

      // 1. Process each item: update inventory, calculate weighted average cost, record stock movement
      for (const item of items) {
        const itemQty = new Decimal(item.quantity);
        const itemPrice = new Decimal(item.purchasePrice);

        const [existingInv] = await queryRunner.query(
          `SELECT * FROM inventory WHERE product_id = $1 AND warehouse_id = $2 FOR UPDATE`,
          [item.product_id, warehouseId],
        );

        let newQty = itemQty;
        let newAvgCost = itemPrice;

        if (existingInv) {
          const oldQty = new Decimal(existingInv.quantity);
          const oldAvgCost = new Decimal(existingInv.average_cost);
          newQty = oldQty.plus(itemQty);

          // Weighted average: (old_qty * old_cost + new_qty * new_cost) / (old_qty + new_qty)
          if (newQty.gt(0)) {
            newAvgCost = oldQty.times(oldAvgCost).plus(itemQty.times(itemPrice)).dividedBy(newQty);
          }

          await queryRunner.query(
            `UPDATE inventory SET quantity = $1, average_cost = $2, last_updated_at = NOW() WHERE id = $3`,
            [newQty.toFixed(2), newAvgCost.toFixed(2), existingInv.id],
          );
        } else {
          await queryRunner.query(
            `INSERT INTO inventory (product_id, warehouse_id, quantity, average_cost) VALUES ($1, $2, $3, $4)`,
            [item.product_id, warehouseId, newQty.toFixed(2), newAvgCost.toFixed(2)],
          );
        }

        // Update purchase_price on product
        await queryRunner.query(
          `UPDATE products SET purchase_price = $1, updated_at = NOW() WHERE id = $2`,
          [itemPrice.toFixed(2), item.product_id],
        );

        // Record stock movement (type=INCOMING)
        await queryRunner.query(
          `INSERT INTO stock_movements (product_id, warehouse_id, type, quantity, balance_after, reference_type, reference_id, reason, created_by)
           VALUES ($1, $2, 'INCOMING', $3, $4, 'SHIPMENT', $5, $6, $7)`,
          [
            item.product_id,
            warehouseId,
            itemQty.toFixed(2),
            newQty.toFixed(2),
            shipmentId,
            `Приход по накладной №${shipment.shipment_number}`,
            userId || null,
          ],
        );

        // Update received quantity
        await queryRunner.query(
          `UPDATE incoming_shipment_items SET received_quantity = quantity WHERE id = $1`,
          [item.id],
        );
      }

      // 2. Create finance transaction (expense) for total shipment cost
      const totalCostDec = new Decimal(shipment.total_amount).plus(new Decimal(shipment.additional_costs));
      if (totalCostDec.gt(0)) {
        // Find default account (cash or bank)
        const [acc] = await queryRunner.query(`SELECT id FROM accounts WHERE is_active = true LIMIT 1`);
        if (acc) {
          await queryRunner.query(
            `INSERT INTO transactions (account_id, type, amount, description, reference_type, reference_id, created_by)
             VALUES ($1, 'EXPENSE', $2, $3, 'SHIPMENT', $4, $5)`,
            [
              acc.id,
              totalCostDec.toFixed(2),
              `Оплата поставки №${shipment.shipment_number}`,
              shipmentId,
              userId || null,
            ],
          );
          // Decrement account balance
          await queryRunner.query(
            `UPDATE accounts SET balance = balance - $1 WHERE id = $2`,
            [totalCostDec.toFixed(2), acc.id],
          );
        }
      }

      // 3. Update supplier balance (our debt to supplier) if supplier exists
      if (shipment.supplier_id) {
        await queryRunner.query(
          `UPDATE suppliers SET balance = balance + $1 WHERE id = $2`,
          [new Decimal(shipment.total_amount).toFixed(2), shipment.supplier_id],
        );
      }

      // 4. Update shipment status to RECEIVED
      await queryRunner.query(
        `UPDATE incoming_shipments SET status = 'RECEIVED', received_date = NOW(), updated_at = NOW() WHERE id = $1`,
        [shipmentId],
      );

      // 5. Audit log
      await queryRunner.query(
        `INSERT INTO audit_logs (user_id, action, entity_name, entity_id, new_values)
         VALUES ($1, 'CONFIRM_RECEIPT', 'SHIPMENT', $2, $3)`,
        [userId || null, shipmentId, JSON.stringify({ status: 'RECEIVED', totalCost: totalCostDec.toNumber() })],
      );

      await queryRunner.commitTransaction();
      return { success: true, message: 'Поставка успешно принята и оприходована на склад' };
    } catch (err) {
      await queryRunner.rollbackTransaction();
      throw err;
    } finally {
      await queryRunner.release();
    }
  }
}
