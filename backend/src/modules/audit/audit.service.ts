import { Injectable } from '@nestjs/common';
import { DataSource } from 'typeorm';

export interface CreateAuditLogDto {
  userId?: string;
  action: string;
  entityName: string;
  entityId?: string;
  oldValues?: any;
  newValues?: any;
  ipAddress?: string;
  userAgent?: string;
}

@Injectable()
export class AuditService {
  constructor(private readonly dataSource: DataSource) {}

  async log(dto: CreateAuditLogDto) {
    try {
      const res = await this.dataSource.query(
        `INSERT INTO audit_logs (user_id, action, entity_name, entity_id, old_values, new_values, ip_address, user_agent)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8) RETURNING *`,
        [
          dto.userId || null,
          dto.action,
          dto.entityName,
          dto.entityId || null,
          dto.oldValues ? JSON.stringify(dto.oldValues) : null,
          dto.newValues ? JSON.stringify(dto.newValues) : null,
          dto.ipAddress || null,
          dto.userAgent || null,
        ],
      );
      return res[0];
    } catch (err) {
      console.error('Failed to create audit log:', err);
      return null;
    }
  }

  async getLogs(query: { entityName?: string; entityId?: string; userId?: string; page?: string; limit?: string }) {
    const limit = parseInt(query.limit || '20', 10);
    const offset = (parseInt(query.page || '1', 10) - 1) * limit;

    const conditions: string[] = ['1=1'];
    const values: any[] = [];
    let idx = 1;

    if (query.entityName) {
      conditions.push(`a.entity_name = $${idx++}`);
      values.push(query.entityName);
    }
    if (query.entityId) {
      conditions.push(`a.entity_id = $${idx++}`);
      values.push(query.entityId);
    }
    if (query.userId) {
      conditions.push(`a.user_id = $${idx++}`);
      values.push(query.userId);
    }

    values.push(limit);
    values.push(offset);

    const logs = await this.dataSource.query(
      `SELECT a.*, u.full_name as user_name, u.email as user_email
       FROM audit_logs a
       LEFT JOIN users u ON a.user_id = u.id
       WHERE ${conditions.join(' AND ')}
       ORDER BY a.created_at DESC
       LIMIT $${idx++} OFFSET $${idx++}`,
      values,
    );

    const [countRes] = await this.dataSource.query(
      `SELECT COUNT(*) as total FROM audit_logs a WHERE ${conditions.join(' AND ')}`,
      values.slice(0, values.length - 2),
    );

    return {
      data: logs,
      meta: {
        total: parseInt(countRes?.total || '0', 10),
        page: parseInt(query.page || '1', 10),
        limit,
      },
    };
  }
}
