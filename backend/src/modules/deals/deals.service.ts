import { Injectable, NotFoundException } from '@nestjs/common';
import { DataSource } from 'typeorm';

@Injectable()
export class DealsService {
  constructor(private readonly dataSource: DataSource) {}

  async getDeals(query: any) {
    const limit = parseInt(query.limit || '50', 10);
    const offset = (parseInt(query.page || '1', 10) - 1) * limit;
    const conditions: string[] = ['1=1'];
    const values: any[] = [];
    let idx = 1;

    if (query.status) {
      conditions.push(`d.status = $${idx++}`);
      values.push(query.status);
    }
    if (query.assignedTo) {
      conditions.push(`d.assigned_to = $${idx++}`);
      values.push(query.assignedTo);
    }

    values.push(limit);
    values.push(offset);

    const data = await this.dataSource.query(
      `SELECT d.*, 
        c.name AS customer_name,
        c.phone AS customer_phone,
        u.full_name AS assigned_to_name
       FROM deals d
       LEFT JOIN customers c ON d.customer_id = c.id
       LEFT JOIN users u ON d.assigned_to = u.id
       WHERE ${conditions.join(' AND ')}
       ORDER BY d.created_at DESC
       LIMIT $${idx++} OFFSET $${idx++}`,
      values,
    );

    const [countRes] = await this.dataSource.query(
      `SELECT COUNT(*) as total FROM deals d WHERE ${conditions.join(' AND ')}`,
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

  async getKanbanBoard() {
    const deals = await this.dataSource.query(
      `SELECT d.*, 
        c.name AS customer_name,
        u.full_name AS assigned_to_name
       FROM deals d
       LEFT JOIN customers c ON d.customer_id = c.id
       LEFT JOIN users u ON d.assigned_to = u.id
       ORDER BY d.created_at DESC`,
    );

    const statuses = ['NEW', 'CONTACT', 'NEGOTIATION', 'PROPOSAL_SENT', 'AWAITING_PAYMENT', 'WON', 'LOST'];
    const kanban: Record<string, any[]> = {};
    for (const status of statuses) {
      kanban[status] = deals.filter((d: any) => d.status === status);
    }
    return kanban;
  }

  async getDealById(id: string) {
    const [deal] = await this.dataSource.query(
      `SELECT d.*, c.name AS customer_name, c.phone AS customer_phone, c.email AS customer_email, u.full_name AS assigned_to_name
       FROM deals d
       LEFT JOIN customers c ON d.customer_id = c.id
       LEFT JOIN users u ON d.assigned_to = u.id
       WHERE d.id = $1`,
      [id],
    );
    if (!deal) throw new NotFoundException('Сделка не найдена');

    const activities = await this.dataSource.query(
      `SELECT da.*, u.full_name AS user_name
       FROM deal_activities da
       LEFT JOIN users u ON da.user_id = u.id
       WHERE da.deal_id = $1
       ORDER BY da.created_at DESC`,
      [id],
    );

    const comments = await this.dataSource.query(
      `SELECT dc.*, u.full_name AS user_name, u.avatar_url
       FROM deal_comments dc
       LEFT JOIN users u ON dc.user_id = u.id
       WHERE dc.deal_id = $1
       ORDER BY dc.created_at ASC`,
      [id],
    );

    return { ...deal, activities, comments };
  }

  async createDeal(
    dto: {
      title: string;
      customerId?: string;
      amount?: number | string;
      status?: string;
      expectedCloseDate?: string;
      assignedTo?: string;
      description?: string;
    },
    userId?: string,
  ) {
    const res = await this.dataSource.query(
      `INSERT INTO deals (title, customer_id, amount, status, expected_close_date, assigned_to, description, created_by)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8) RETURNING *`,
      [
        dto.title,
        dto.customerId || null,
        dto.amount || 0,
        dto.status || 'NEW',
        dto.expectedCloseDate || null,
        dto.assignedTo || userId || null,
        dto.description || null,
        userId || null,
      ],
    );
    const deal = res[0];

    // Log creation activity
    await this.dataSource.query(
      `INSERT INTO deal_activities (deal_id, type, description, user_id)
       VALUES ($1, 'CREATE', 'Сделка создана', $2)`,
      [deal.id, userId || null],
    );

    return deal;
  }

  async updateDeal(id: string, dto: any, userId?: string) {
    const current = await this.getDealById(id);
    const fields: string[] = [];
    const values: any[] = [];
    let idx = 1;

    for (const [key, val] of Object.entries(dto)) {
      if (['title', 'customer_id', 'amount', 'expected_close_date', 'assigned_to', 'description'].includes(key)) {
        fields.push(`${key} = $${idx++}`);
        values.push(val);
      }
    }
    if (fields.length === 0) return current;

    values.push(id);
    const [updated] = await this.dataSource.query(
      `UPDATE deals SET ${fields.join(', ')}, updated_at = NOW() WHERE id = $${idx} RETURNING *`,
      values,
    );

    return updated;
  }

  async updateStatus(id: string, status: string, userId?: string) {
    const [deal] = await this.dataSource.query(`SELECT * FROM deals WHERE id = $1`, [id]);
    if (!deal) throw new NotFoundException('Сделка не найдена');

    const [updated] = await this.dataSource.query(
      `UPDATE deals SET status = $1, updated_at = NOW() WHERE id = $2 RETURNING *`,
      [status, id],
    );

    // Record activity
    await this.dataSource.query(
      `INSERT INTO deal_activities (deal_id, type, description, user_id)
       VALUES ($1, 'STATUS_CHANGE', $2, $3)`,
      [id, `Статус изменен с ${deal.status} на ${status}`, userId || null],
    );

    return updated;
  }

  async addComment(dealId: string, content: string, userId: string) {
    await this.getDealById(dealId);
    const res = await this.dataSource.query(
      `INSERT INTO deal_comments (deal_id, user_id, content) VALUES ($1, $2, $3) RETURNING *`,
      [dealId, userId, content],
    );
    return res[0];
  }
}
