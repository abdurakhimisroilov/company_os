import { Injectable, NotFoundException, BadRequestException, ForbiddenException } from '@nestjs/common';
import { DataSource } from 'typeorm';
import * as bcrypt from 'bcryptjs';

@Injectable()
export class EmployeesService {
  constructor(private readonly dataSource: DataSource) {}

  async getEmployees(query: any) {
    const search = query.search ? `%${query.search}%` : null;
    const limit = parseInt(query.limit || '50', 10);
    const offset = (parseInt(query.page || '1', 10) - 1) * limit;

    const employees = await this.dataSource.query(
      `SELECT 
        u.id, u.email, u.full_name, u.phone, u.role, u.department_id, u.avatar_url, u.is_active, u.created_at,
        d.name AS department_name
       FROM users u
       LEFT JOIN departments d ON u.department_id = d.id
       WHERE ($1::text IS NULL OR u.full_name ILIKE $1 OR u.email ILIKE $1 OR u.phone ILIKE $1)
       ORDER BY u.full_name ASC
       LIMIT $2 OFFSET $3`,
      [search, limit, offset],
    );

    const [countRes] = await this.dataSource.query(
      `SELECT COUNT(*) as total FROM users WHERE ($1::text IS NULL OR full_name ILIKE $1 OR email ILIKE $1 OR phone ILIKE $1)`,
      [search],
    );

    return {
      data: employees,
      meta: {
        total: parseInt(countRes?.total || '0', 10),
        page: parseInt(query.page || '1', 10),
        limit,
      },
    };
  }

  async getEmployeeById(id: string) {
    const [user] = await this.dataSource.query(
      `SELECT 
        u.id, u.email, u.full_name, u.phone, u.role, u.department_id, u.avatar_url, u.is_active, u.created_at,
        d.name AS department_name
       FROM users u
       LEFT JOIN departments d ON u.department_id = d.id
       WHERE u.id = $1`,
      [id],
    );
    if (!user) throw new NotFoundException('Сотрудник не найден');
    return user;
  }

  async createEmployee(dto: {
    email: string;
    password?: string;
    fullName: string;
    phone?: string;
    role?: string;
    departmentId?: string;
    avatarUrl?: string;
  }) {
    const [existing] = await this.dataSource.query(`SELECT id FROM users WHERE email = $1`, [dto.email]);
    if (existing) {
      throw new BadRequestException('Пользователь с таким email уже существует');
    }

    const rawPassword = dto.password || 'Employee123!';
    const passwordHash = await bcrypt.hash(rawPassword, 10);

    const [user] = await this.dataSource.query(
      `INSERT INTO users (email, password_hash, full_name, phone, role, department_id, avatar_url, is_active)
       VALUES ($1, $2, $3, $4, $5, $6, $7, true)
       RETURNING id, email, full_name, phone, role, department_id, avatar_url, is_active, created_at`,
      [
        dto.email,
        passwordHash,
        dto.fullName,
        dto.phone || null,
        dto.role || 'EMPLOYEE',
        dto.departmentId || null,
        dto.avatarUrl || null,
      ],
    );

    // Welcome notification
    await this.dataSource.query(
      `INSERT INTO notifications (user_id, title, body, type, reference_id)
       VALUES ($1, 'Добро пожаловать!', 'Ваш аккаунт в Company OS успешно создан.', 'SYSTEM', $1)`,
      [user.id],
    );

    return user;
  }

  async updateEmployee(id: string, dto: any) {
    await this.getEmployeeById(id);
    const fields: string[] = [];
    const values: any[] = [];
    let idx = 1;

    for (const [key, val] of Object.entries(dto)) {
      if (['fullName', 'phone', 'departmentId', 'avatarUrl'].includes(key)) {
        const col = key === 'fullName' ? 'full_name' : key === 'departmentId' ? 'department_id' : key === 'avatarUrl' ? 'avatar_url' : key;
        fields.push(`${col} = $${idx++}`);
        values.push(val);
      }
    }

    if (fields.length === 0) return this.getEmployeeById(id);

    values.push(id);
    const [updated] = await this.dataSource.query(
      `UPDATE users SET ${fields.join(', ')}, updated_at = NOW() WHERE id = $${idx}
       RETURNING id, email, full_name, phone, role, department_id, avatar_url, is_active, created_at`,
      values,
    );
    return updated;
  }

  async updateRole(id: string, role: string, actorRole: string) {
    if (actorRole !== 'SUPER_ADMIN') {
      throw new ForbiddenException('Только Главный Администратор может изменять роли пользователей');
    }
    const [updated] = await this.dataSource.query(
      `UPDATE users SET role = $1, updated_at = NOW() WHERE id = $2
       RETURNING id, email, full_name, role`,
      [role, id],
    );
    return updated;
  }

  async deactivateEmployee(id: string) {
    await this.dataSource.query(`UPDATE users SET is_active = false, updated_at = NOW() WHERE id = $1`, [id]);
    return { success: true, message: 'Сотрудник деактивирован' };
  }

  async getDepartments() {
    return this.dataSource.query(
      `SELECT d.*, 
        (SELECT COUNT(*) FROM users u WHERE u.department_id = d.id AND u.is_active = true) AS employee_count
       FROM departments d
       ORDER BY d.name ASC`,
    );
  }

  async createDepartment(dto: { name: string; description?: string }) {
    const res = await this.dataSource.query(
      `INSERT INTO departments (name, description) VALUES ($1, $2) RETURNING *`,
      [dto.name, dto.description || null],
    );
    return res[0];
  }

  async assignManager(departmentId: string, employeeId: string) {
    await this.dataSource.query(
      `UPDATE users SET role = 'DEPARTMENT_MANAGER', department_id = $1 WHERE id = $2`,
      [departmentId, employeeId],
    );
    return { success: true, message: 'Руководитель назначен' };
  }

  async getEmployeeStats(id: string) {
    await this.getEmployeeById(id);

    const [tasksCompleted] = await this.dataSource.query(
      `SELECT COUNT(*) AS count FROM tasks WHERE assigned_to = $1 AND status = 'DONE'`,
      [id],
    );
    const [tasksPending] = await this.dataSource.query(
      `SELECT COUNT(*) AS count FROM tasks WHERE assigned_to = $1 AND status != 'DONE'`,
      [id],
    );
    const recentActivities = await this.dataSource.query(
      `SELECT action, entity_name, created_at FROM audit_logs WHERE user_id = $1 ORDER BY created_at DESC LIMIT 10`,
      [id],
    );

    return {
      tasksCompleted: parseInt(tasksCompleted?.count || '0', 10),
      tasksPending: parseInt(tasksPending?.count || '0', 10),
      recentActivities,
    };
  }
}
