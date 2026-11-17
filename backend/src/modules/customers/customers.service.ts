import { Injectable, NotFoundException } from '@nestjs/common';
import { DataSource } from 'typeorm';
import { CreateCustomerDto } from './dto/create-customer.dto';
import { UpdateCustomerDto } from './dto/update-customer.dto';

@Injectable()
export class CustomersService {
  constructor(private readonly dataSource: DataSource) {}

  async findAll(query: any) {
    const search = query.search ? `%${query.search}%` : null;
    const limit = parseInt(query.limit || '50', 10);
    const offset = (parseInt(query.page || '1', 10) - 1) * limit;

    const customers = await this.dataSource.query(
      `SELECT c.*,
        COALESCE((SELECT COUNT(*) FROM sales s WHERE s.customer_id = c.id), 0) AS total_orders,
        COALESCE((SELECT SUM(s.grand_total) FROM sales s WHERE s.customer_id = c.id), 0) AS total_spent
       FROM customers c
       WHERE ($1::text IS NULL OR c.name ILIKE $1 OR c.phone ILIKE $1 OR c.inn ILIKE $1)
       ORDER BY c.name ASC
       LIMIT $2 OFFSET $3`,
      [search, limit, offset],
    );

    const [countRes] = await this.dataSource.query(
      `SELECT COUNT(*) as total FROM customers WHERE ($1::text IS NULL OR name ILIKE $1 OR phone ILIKE $1 OR inn ILIKE $1)`,
      [search],
    );

    return {
      data: customers,
      meta: {
        total: parseInt(countRes?.total || '0', 10),
        page: parseInt(query.page || '1', 10),
        limit,
      },
    };
  }

  async findOne(id: string) {
    const [customer] = await this.dataSource.query(
      `SELECT * FROM customers WHERE id = $1`,
      [id],
    );
    if (!customer) {
      throw new NotFoundException('Клиент не найден');
    }
    return customer;
  }

  async create(dto: CreateCustomerDto, userId?: string) {
    const res = await this.dataSource.query(
      `INSERT INTO customers (name, phone, email, address, inn, notes, balance)
       VALUES ($1, $2, $3, $4, $5, $6, 0.00) RETURNING *`,
      [
        dto.name,
        dto.phone || null,
        dto.email || null,
        dto.address || null,
        dto.inn || null,
        dto.notes || null,
      ],
    );
    return res[0];
  }

  async update(id: string, dto: UpdateCustomerDto, userId?: string) {
    await this.findOne(id);
    const fields: string[] = [];
    const values: any[] = [];
    let idx = 1;

    for (const [key, val] of Object.entries(dto)) {
      if (['name', 'phone', 'email', 'address', 'inn', 'notes'].includes(key)) {
        fields.push(`${key} = $${idx++}`);
        values.push(val);
      }
    }

    if (fields.length === 0) return this.findOne(id);

    values.push(id);
    const [updated] = await this.dataSource.query(
      `UPDATE customers SET ${fields.join(', ')} WHERE id = $${idx} RETURNING *`,
      values,
    );
    return updated;
  }

  async remove(id: string) {
    await this.findOne(id);
    await this.dataSource.query(`DELETE FROM customers WHERE id = $1`, [id]);
    return { success: true, message: 'Клиент удален' };
  }

  async getPurchaseHistory(id: string) {
    await this.findOne(id);
    return this.dataSource.query(
      `SELECT s.*,
        (SELECT json_agg(si.*) FROM sale_items si WHERE si.sale_id = s.id) AS items
       FROM sales s
       WHERE s.customer_id = $1
       ORDER BY s.created_at DESC`,
      [id],
    );
  }

  async getCustomerDebt(id: string) {
    const customer = await this.findOne(id);
    const [debtRes] = await this.dataSource.query(
      `SELECT 
        COALESCE(SUM(grand_total - paid_amount), 0) AS total_unpaid_sales
       FROM sales 
       WHERE customer_id = $1 AND payment_status != 'PAID'`,
      [id],
    );

    return {
      customerId: id,
      customerName: customer.name,
      balance: customer.balance,
      unpaidSales: parseFloat(debtRes?.total_unpaid_sales || '0'),
    };
  }
}
