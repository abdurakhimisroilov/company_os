import { Injectable, NotFoundException } from '@nestjs/common';
import { DataSource } from 'typeorm';
import { CreateSupplierDto } from './dto/create-supplier.dto';
import { UpdateSupplierDto } from './dto/update-supplier.dto';

@Injectable()
export class SuppliersService {
  constructor(private readonly dataSource: DataSource) {}

  async findAll(query: any) {
    const search = query.search ? `%${query.search}%` : null;
    const limit = parseInt(query.limit || '50', 10);
    const offset = (parseInt(query.page || '1', 10) - 1) * limit;

    const suppliers = await this.dataSource.query(
      `SELECT s.*,
        COALESCE((SELECT COUNT(*) FROM incoming_shipments ish WHERE ish.supplier_id = s.id), 0) AS total_shipments,
        COALESCE((SELECT SUM(ish.total_amount) FROM incoming_shipments ish WHERE ish.supplier_id = s.id), 0) AS total_purchased
       FROM suppliers s
       WHERE ($1::text IS NULL OR s.name ILIKE $1 OR s.contact_person ILIKE $1 OR s.phone ILIKE $1)
       ORDER BY s.name ASC
       LIMIT $2 OFFSET $3`,
      [search, limit, offset],
    );

    const [countRes] = await this.dataSource.query(
      `SELECT COUNT(*) as total FROM suppliers WHERE ($1::text IS NULL OR name ILIKE $1 OR contact_person ILIKE $1 OR phone ILIKE $1)`,
      [search],
    );

    return {
      data: suppliers,
      meta: {
        total: parseInt(countRes?.total || '0', 10),
        page: parseInt(query.page || '1', 10),
        limit,
      },
    };
  }

  async findOne(id: string) {
    const [supplier] = await this.dataSource.query(
      `SELECT * FROM suppliers WHERE id = $1`,
      [id],
    );
    if (!supplier) {
      throw new NotFoundException('Поставщик не найден');
    }
    return supplier;
  }

  async create(dto: CreateSupplierDto) {
    const res = await this.dataSource.query(
      `INSERT INTO suppliers (name, contact_person, phone, email, address, inn, balance)
       VALUES ($1, $2, $3, $4, $5, $6, 0.00) RETURNING *`,
      [
        dto.name,
        dto.contactPerson || null,
        dto.phone || null,
        dto.email || null,
        dto.address || null,
        dto.inn || null,
      ],
    );
    return res[0];
  }

  async update(id: string, dto: UpdateSupplierDto) {
    await this.findOne(id);
    const fields: string[] = [];
    const values: any[] = [];
    let idx = 1;

    for (const [key, val] of Object.entries(dto)) {
      if (['name', 'contactPerson', 'phone', 'email', 'address', 'inn'].includes(key)) {
        const col = key === 'contactPerson' ? 'contact_person' : key;
        fields.push(`${col} = $${idx++}`);
        values.push(val);
      }
    }

    if (fields.length === 0) return this.findOne(id);

    values.push(id);
    const [updated] = await this.dataSource.query(
      `UPDATE suppliers SET ${fields.join(', ')} WHERE id = $${idx} RETURNING *`,
      values,
    );
    return updated;
  }

  async remove(id: string) {
    await this.findOne(id);
    await this.dataSource.query(`DELETE FROM suppliers WHERE id = $1`, [id]);
    return { success: true, message: 'Поставщик удален' };
  }

  async getShipmentHistory(id: string) {
    await this.findOne(id);
    return this.dataSource.query(
      `SELECT ish.*,
        (SELECT json_agg(isi.*) FROM incoming_shipment_items isi WHERE isi.shipment_id = ish.id) AS items
       FROM incoming_shipments ish
       WHERE ish.supplier_id = $1
       ORDER BY ish.created_at DESC`,
      [id],
    );
  }

  async getPayables(id: string) {
    const supplier = await this.findOne(id);
    const [payablesRes] = await this.dataSource.query(
      `SELECT 
        COALESCE(SUM(total_amount + additional_costs), 0) AS total_shipment_costs
       FROM incoming_shipments 
       WHERE supplier_id = $1 AND status != 'CANCELLED'`,
      [id],
    );

    const [paidRes] = await this.dataSource.query(
      `SELECT COALESCE(SUM(amount), 0) AS total_paid
       FROM payments
       WHERE supplier_id = $1 AND type = 'OUTGOING'`,
      [id],
    );

    const totalCost = parseFloat(payablesRes?.total_shipment_costs || '0');
    const totalPaid = parseFloat(paidRes?.total_paid || '0');
    const calculatedPayable = Math.max(0, totalCost - totalPaid);

    return {
      supplierId: id,
      supplierName: supplier.name,
      balance: supplier.balance,
      calculatedPayables: calculatedPayable,
    };
  }
}
