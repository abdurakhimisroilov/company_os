import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { DataSource } from 'typeorm';
import Decimal from 'decimal.js';

@Injectable()
export class InventoryService {
  constructor(private readonly dataSource: DataSource) {}

  async getProducts(query: any) {
    const search = query.search ? `%${query.search}%` : null;
    const limit = parseInt(query.limit || '50', 10);
    const offset = (parseInt(query.page || '1', 10) - 1) * limit;

    const products = await this.dataSource.query(
      `SELECT p.*, 
        COALESCE(SUM(i.quantity), 0) AS stock_quantity,
        COALESCE(AVG(i.average_cost), 0) AS avg_cost,
        pc.name AS category_name
       FROM products p
       LEFT JOIN inventory i ON p.id = i.product_id
       LEFT JOIN product_categories pc ON p.category_id = pc.id
       WHERE p.is_active = true
         AND ($1::text IS NULL OR p.name ILIKE $1 OR p.sku ILIKE $1 OR p.barcode ILIKE $1)
       GROUP BY p.id, pc.name
       ORDER BY p.name ASC
       LIMIT $2 OFFSET $3`,
      [search, limit, offset],
    );

    const [countRes] = await this.dataSource.query(
      `SELECT COUNT(*) as total FROM products WHERE is_active = true AND ($1::text IS NULL OR name ILIKE $1 OR sku ILIKE $1 OR barcode ILIKE $1)`,
      [search],
    );

    return {
      data: products,
      meta: {
        total: parseInt(countRes?.total || '0', 10),
        page: parseInt(query.page || '1', 10),
        limit,
      },
    };
  }

  async getProductById(id: string) {
    const [product] = await this.dataSource.query(
      `SELECT p.*, 
        COALESCE(SUM(i.quantity), 0) AS stock_quantity,
        COALESCE(AVG(i.average_cost), 0) AS avg_cost,
        pc.name AS category_name
       FROM products p
       LEFT JOIN inventory i ON p.id = i.product_id
       LEFT JOIN product_categories pc ON p.category_id = pc.id
       WHERE p.id = $1
       GROUP BY p.id, pc.name`,
      [id],
    );
    if (!product) throw new NotFoundException('Товар не найден');

    const movements = await this.dataSource.query(
      `SELECT m.*, u.full_name AS created_by_name
       FROM stock_movements m
       LEFT JOIN users u ON m.created_by = u.id
       WHERE m.product_id = $1
       ORDER BY m.created_at DESC
       LIMIT 20`,
      [id],
    );

    return { ...product, movements };
  }

  async createProduct(dto: {
    name: string;
    sku: string;
    categoryId?: string;
    purchasePrice?: number | string;
    sellingPrice?: number | string;
    minStockLevel?: number;
    barcode?: string;
    unit?: string;
    description?: string;
    imageUrl?: string;
    initialStock?: number;
  }, userId?: string) {
    const queryRunner = this.dataSource.createQueryRunner();
    await queryRunner.connect();
    await queryRunner.startTransaction();

    try {
      const [product] = await queryRunner.query(
        `INSERT INTO products (name, sku, category_id, purchase_price, selling_price, min_stock_level, barcode, unit, description, image_url)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10) RETURNING *`,
        [
          dto.name,
          dto.sku,
          dto.categoryId || null,
          dto.purchasePrice || 0,
          dto.sellingPrice || 0,
          dto.minStockLevel || 5,
          dto.barcode || null,
          dto.unit || 'шт',
          dto.description || null,
          dto.imageUrl || null,
        ],
      );

      // Get or create default warehouse
      let [warehouse] = await queryRunner.query(`SELECT id FROM warehouses LIMIT 1`);
      if (!warehouse) {
        [warehouse] = await queryRunner.query(
          `INSERT INTO warehouses (name, is_default) VALUES ('Основной склад', true) RETURNING id`,
        );
      }

      const initialQty = dto.initialStock ? new Decimal(dto.initialStock) : new Decimal(0);
      const avgCost = dto.purchasePrice ? new Decimal(dto.purchasePrice) : new Decimal(0);

      await queryRunner.query(
        `INSERT INTO inventory (product_id, warehouse_id, quantity, average_cost)
         VALUES ($1, $2, $3, $4)`,
        [product.id, warehouse.id, initialQty.toFixed(2), avgCost.toFixed(2)],
      );

      if (initialQty.gt(0)) {
        await queryRunner.query(
          `INSERT INTO stock_movements (product_id, warehouse_id, type, quantity, balance_after, reason, created_by)
           VALUES ($1, $2, 'INCOMING', $3, $3, 'Начальный остаток', $4)`,
          [product.id, warehouse.id, initialQty.toFixed(2), userId || null],
        );
      }

      // Audit log
      await queryRunner.query(
        `INSERT INTO audit_logs (user_id, action, entity_name, entity_id, new_values)
         VALUES ($1, 'CREATE', 'PRODUCT', $2, $3)`,
        [userId || null, product.id, JSON.stringify(product)],
      );

      await queryRunner.commitTransaction();
      return product;
    } catch (err) {
      await queryRunner.rollbackTransaction();
      throw err;
    } finally {
      await queryRunner.release();
    }
  }

  async updateProduct(id: string, dto: any, userId?: string) {
    const current = await this.getProductById(id);
    const fields: string[] = [];
    const values: any[] = [];
    let idx = 1;

    for (const [key, val] of Object.entries(dto)) {
      if (['name', 'sku', 'purchase_price', 'selling_price', 'min_stock_level', 'unit', 'barcode', 'description', 'image_url'].includes(key)) {
        fields.push(`${key} = $${idx++}`);
        values.push(val);
      }
    }
    if (fields.length === 0) return current;

    values.push(id);
    const [updated] = await this.dataSource.query(
      `UPDATE products SET ${fields.join(', ')}, updated_at = NOW() WHERE id = $${idx} RETURNING *`,
      values,
    );

    // Audit log
    await this.dataSource.query(
      `INSERT INTO audit_logs (user_id, action, entity_name, entity_id, old_values, new_values)
       VALUES ($1, 'UPDATE', 'PRODUCT', $2, $3, $4)`,
      [userId || null, id, JSON.stringify(current), JSON.stringify(updated)],
    );

    return updated;
  }

  async adjustStock(
    dto: { productId: string; warehouseId?: string; quantity: number | string; reason: string; unitCost?: number | string },
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

      const [inv] = await queryRunner.query(
        `SELECT * FROM inventory WHERE product_id = $1 AND warehouse_id = $2`,
        [dto.productId, warehouseId],
      );

      const currentQty = new Decimal(inv?.quantity || 0);
      const currentAvgCost = new Decimal(inv?.average_cost || 0);
      const adjustment = new Decimal(dto.quantity);
      const newQty = currentQty.plus(adjustment);

      if (newQty.lt(0)) {
        throw new BadRequestException('Количество на складе не может быть отрицательным');
      }

      let newAvgCost = currentAvgCost;
      if (adjustment.gt(0) && dto.unitCost) {
        const cost = new Decimal(dto.unitCost);
        // Weighted average formula: (old_qty * old_cost + new_qty * new_cost) / (old_qty + new_qty)
        const totalOldValue = currentQty.times(currentAvgCost);
        const addedValue = adjustment.times(cost);
        newAvgCost = totalOldValue.plus(addedValue).dividedBy(newQty);
      }

      if (inv) {
        await queryRunner.query(
          `UPDATE inventory SET quantity = $1, average_cost = $2, last_updated_at = NOW() WHERE id = $3`,
          [newQty.toFixed(2), newAvgCost.toFixed(2), inv.id],
        );
      } else {
        await queryRunner.query(
          `INSERT INTO inventory (product_id, warehouse_id, quantity, average_cost) VALUES ($1, $2, $3, $4)`,
          [dto.productId, warehouseId, newQty.toFixed(2), newAvgCost.toFixed(2)],
        );
      }

      const [movement] = await queryRunner.query(
        `INSERT INTO stock_movements (product_id, warehouse_id, type, quantity, balance_after, reason, created_by)
         VALUES ($1, $2, 'ADJUSTMENT', $3, $4, $5, $6) RETURNING *`,
        [dto.productId, warehouseId, adjustment.toFixed(2), newQty.toFixed(2), dto.reason, userId || null],
      );

      // Audit log
      await queryRunner.query(
        `INSERT INTO audit_logs (user_id, action, entity_name, entity_id, new_values)
         VALUES ($1, 'STOCK_ADJUSTMENT', 'INVENTORY', $2, $3)`,
        [userId || null, dto.productId, JSON.stringify({ oldQty: currentQty.toNumber(), newQty: newQty.toNumber(), reason: dto.reason })],
      );

      await queryRunner.commitTransaction();
      return { inventory: { quantity: newQty.toNumber(), averageCost: newAvgCost.toNumber() }, movement };
    } catch (err) {
      await queryRunner.rollbackTransaction();
      throw err;
    } finally {
      await queryRunner.release();
    }
  }

  async getLowStockProducts() {
    return this.dataSource.query(
      `SELECT p.id, p.name, p.sku, p.min_stock_level, COALESCE(SUM(i.quantity), 0) AS current_stock
       FROM products p
       LEFT JOIN inventory i ON p.id = i.product_id
       WHERE p.is_active = true
       GROUP BY p.id
       HAVING COALESCE(SUM(i.quantity), 0) <= p.min_stock_level`,
    );
  }

  async getInventoryValue() {
    const res = await this.dataSource.query(`
      SELECT 
        pc.id AS category_id,
        COALESCE(pc.name, 'Без категории') AS category_name,
        COALESCE(SUM(i.quantity * i.average_cost), 0) AS category_value,
        COALESCE(SUM(i.quantity), 0) AS total_items
      FROM inventory i
      JOIN products p ON i.product_id = p.id
      LEFT JOIN product_categories pc ON p.category_id = pc.id
      GROUP BY pc.id, pc.name
    `);

    const [total] = await this.dataSource.query(
      `SELECT COALESCE(SUM(quantity * average_cost), 0) AS grand_total_value FROM inventory`,
    );

    return {
      byCategory: res,
      totalValue: parseFloat(total?.grand_total_value || '0'),
    };
  }

  async getStockMovements(productId: string, query: any) {
    const limit = parseInt(query.limit || '20', 10);
    const offset = (parseInt(query.page || '1', 10) - 1) * limit;

    const data = await this.dataSource.query(
      `SELECT sm.*, u.full_name AS created_by_name, w.name AS warehouse_name
       FROM stock_movements sm
       LEFT JOIN users u ON sm.created_by = u.id
       LEFT JOIN warehouses w ON sm.warehouse_id = w.id
       WHERE sm.product_id = $1
       ORDER BY sm.created_at DESC
       LIMIT $2 OFFSET $3`,
      [productId, limit, offset],
    );

    const [countRes] = await this.dataSource.query(
      `SELECT COUNT(*) AS total FROM stock_movements WHERE product_id = $1`,
      [productId],
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
}
