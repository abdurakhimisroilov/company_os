import { Injectable, NotFoundException, ForbiddenException, BadRequestException } from '@nestjs/common';
import { DataSource } from 'typeorm';

@Injectable()
export class TasksService {
  constructor(private readonly dataSource: DataSource) {}

  async getTasks(query: any, currentUserId?: string) {
    const limit = parseInt(query.limit || '50', 10);
    const offset = (parseInt(query.page || '1', 10) - 1) * limit;
    const conditions: string[] = ['1=1'];
    const values: any[] = [];
    let idx = 1;

    if (query.status) {
      conditions.push(`t.status = $${idx++}`);
      values.push(query.status);
    }
    if (query.priority) {
      conditions.push(`t.priority = $${idx++}`);
      values.push(query.priority);
    }
    if (query.assignedTo) {
      conditions.push(`t.assigned_to = $${idx++}`);
      values.push(query.assignedTo);
    }
    if (query.createdBy) {
      conditions.push(`t.created_by = $${idx++}`);
      values.push(query.createdBy);
    }
    if (query.departmentId) {
      conditions.push(`u_assign.department_id = $${idx++}`);
      values.push(query.departmentId);
    }

    values.push(limit);
    values.push(offset);

    const data = await this.dataSource.query(
      `SELECT t.*, 
        u_assign.full_name AS assigned_to_name,
        u_assign.avatar_url AS assigned_to_avatar,
        u_create.full_name AS created_by_name,
        (SELECT COUNT(*) FROM task_comments tc WHERE tc.task_id = t.id) AS comment_count,
        (SELECT COUNT(*) FROM task_attachments ta WHERE ta.task_id = t.id) AS attachment_count
       FROM tasks t
       LEFT JOIN users u_assign ON t.assigned_to = u_assign.id
       LEFT JOIN users u_create ON t.created_by = u_create.id
       WHERE ${conditions.join(' AND ')}
       ORDER BY 
         CASE WHEN t.priority = 'URGENT' THEN 1 WHEN t.priority = 'HIGH' THEN 2 WHEN t.priority = 'MEDIUM' THEN 3 ELSE 4 END,
         t.due_date ASC NULLS LAST,
         t.created_at DESC
       LIMIT $${idx++} OFFSET $${idx++}`,
      values,
    );

    const [countRes] = await this.dataSource.query(
      `SELECT COUNT(*) as total 
       FROM tasks t 
       LEFT JOIN users u_assign ON t.assigned_to = u_assign.id
       WHERE ${conditions.join(' AND ')}`,
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

  async getOverdueTasks() {
    return this.dataSource.query(
      `SELECT t.*, u_assign.full_name AS assigned_to_name
       FROM tasks t
       LEFT JOIN users u_assign ON t.assigned_to = u_assign.id
       WHERE t.due_date < NOW() AND t.status != 'DONE'
       ORDER BY t.due_date ASC`,
    );
  }

  async getTaskById(id: string) {
    const [task] = await this.dataSource.query(
      `SELECT t.*, 
        u_assign.full_name AS assigned_to_name,
        u_create.full_name AS created_by_name
       FROM tasks t
       LEFT JOIN users u_assign ON t.assigned_to = u_assign.id
       LEFT JOIN users u_create ON t.created_by = u_create.id
       WHERE t.id = $1`,
      [id],
    );
    if (!task) throw new NotFoundException('Задача не найдена');

    const comments = await this.dataSource.query(
      `SELECT tc.*, u.full_name AS user_name, u.avatar_url
       FROM task_comments tc
       JOIN users u ON tc.user_id = u.id
       WHERE tc.task_id = $1
       ORDER BY tc.created_at ASC`,
      [id],
    );

    const attachments = await this.dataSource.query(
      `SELECT ta.*, u.full_name AS uploaded_by_name
       FROM task_attachments ta
       LEFT JOIN users u ON ta.uploaded_by = u.id
       WHERE ta.task_id = $1`,
      [id],
    );

    return { ...task, comments, attachments };
  }

  async createTask(
    dto: {
      title: string;
      description?: string;
      priority?: string;
      assignedTo?: string;
      dueDate?: string;
    },
    userId?: string,
  ) {
    const res = await this.dataSource.query(
      `INSERT INTO tasks (title, description, priority, status, assigned_to, due_date, progress, created_by)
       VALUES ($1, $2, $3, 'NEW', $4, $5, 0, $6) RETURNING *`,
      [
        dto.title,
        dto.description || null,
        dto.priority || 'MEDIUM',
        dto.assignedTo || null,
        dto.dueDate || null,
        userId || null,
      ],
    );
    const task = res[0];

    // Send in-app notification to assignee
    if (dto.assignedTo) {
      await this.dataSource.query(
        `INSERT INTO notifications (user_id, title, body, type, reference_id)
         VALUES ($1, $2, $3, 'TASK', $4)`,
        [
          dto.assignedTo,
          'Вам назначена новая задача',
          dto.title,
          task.id,
        ],
      );
    }

    return task;
  }

  async updateStatus(id: string, status: string, progress?: number, userId?: string) {
    const task = await this.getTaskById(id);
    const newProgress = progress !== undefined ? progress : status === 'DONE' ? 100 : task.progress;

    const [updated] = await this.dataSource.query(
      `UPDATE tasks SET status = $1, progress = $2, updated_at = NOW() WHERE id = $3 RETURNING *`,
      [status, newProgress, id],
    );

    // Notify task creator if someone else updated status
    if (task.created_by && task.created_by !== userId) {
      await this.dataSource.query(
        `INSERT INTO notifications (user_id, title, body, type, reference_id)
         VALUES ($1, $2, $3, 'TASK', $4)`,
        [
          task.created_by,
          `Статус задачи изменен на "${status}"`,
          task.title,
          id,
        ],
      );
    }

    return updated;
  }

  async approveTask(id: string, userRole: string, userId?: string) {
    if (!['SUPER_ADMIN', 'ADMIN', 'DEPARTMENT_MANAGER'].includes(userRole)) {
      throw new ForbiddenException('Только руководители могут утверждать задачи');
    }
    return this.updateStatus(id, 'DONE', 100, userId);
  }

  async returnTask(id: string, reason: string, userRole: string, userId?: string) {
    if (!['SUPER_ADMIN', 'ADMIN', 'DEPARTMENT_MANAGER'].includes(userRole)) {
      throw new ForbiddenException('Только руководители могут возвращать задачи');
    }
    const task = await this.getTaskById(id);
    const [updated] = await this.dataSource.query(
      `UPDATE tasks SET status = 'REJECTED', updated_at = NOW() WHERE id = $1 RETURNING *`,
      [id],
    );

    // Add comment with rejection reason
    await this.addComment(id, `Задача возвращена на доработку: ${reason}`, userId || task.created_by);

    if (task.assigned_to) {
      await this.dataSource.query(
        `INSERT INTO notifications (user_id, title, body, type, reference_id)
         VALUES ($1, $2, $3, 'TASK', $4)`,
        [
          task.assigned_to,
          'Задача возвращена на доработку',
          `${task.title}: ${reason}`,
          id,
        ],
      );
    }

    return updated;
  }

  async addComment(taskId: string, content: string, userId: string) {
    await this.getTaskById(taskId);
    const res = await this.dataSource.query(
      `INSERT INTO task_comments (task_id, user_id, content) VALUES ($1, $2, $3) RETURNING *`,
      [taskId, userId, content],
    );
    return res[0];
  }

  async uploadAttachment(
    taskId: string,
    file: { fileName: string; fileUrl: string; fileSize?: number; mimeType?: string },
    userId?: string,
  ) {
    await this.getTaskById(taskId);
    const res = await this.dataSource.query(
      `INSERT INTO task_attachments (task_id, file_name, file_url, file_size, mime_type, uploaded_by)
       VALUES ($1, $2, $3, $4, $5, $6) RETURNING *`,
      [
        taskId,
        file.fileName,
        file.fileUrl,
        file.fileSize || 0,
        file.mimeType || 'application/octet-stream',
        userId || null,
      ],
    );
    return res[0];
  }
}
