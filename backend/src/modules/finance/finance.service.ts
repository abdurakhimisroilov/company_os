import { Injectable, BadRequestException, NotFoundException } from '@nestjs/common';
import { DataSource } from 'typeorm';
import Decimal from 'decimal.js';

@Injectable()
export class FinanceService {
  constructor(private readonly dataSource: DataSource) {}

  async getAccounts() {
    return this.dataSource.query(`SELECT * FROM accounts WHERE is_active = true ORDER BY name ASC`);
  }

  async getAccountBalances() {
    return this.getAccounts();
  }

  async createAccount(dto: { name: string; type: string; accountNumber?: string; currency?: string }) {
    const res = await this.dataSource.query(
      `INSERT INTO accounts (name, type, account_number, currency, balance)
       VALUES ($1, $2, $3, $4, 0.00) RETURNING *`,
      [dto.name, dto.type, dto.accountNumber || null, dto.currency || 'UZS'],
    );
    return res[0];
  }

  async getTransactions(query: any) {
    const limit = parseInt(query.limit || '20', 10);
    const offset = (parseInt(query.page || '1', 10) - 1) * limit;
    const conditions: string[] = ['1=1'];
    const values: any[] = [];
    let idx = 1;

    if (query.type) {
      conditions.push(`t.type = $${idx++}`);
      values.push(query.type);
    }
    if (query.startDate) {
      conditions.push(`t.transaction_date >= $${idx++}`);
      values.push(query.startDate);
    }
    if (query.endDate) {
      conditions.push(`t.transaction_date <= $${idx++}`);
      values.push(query.endDate);
    }
    if (query.category) {
      conditions.push(`t.category_id = $${idx++}`);
      values.push(query.category);
    }

    values.push(limit);
    values.push(offset);

    const data = await this.dataSource.query(
      `SELECT t.*, a.name AS account_name, u.full_name AS created_by_name
       FROM transactions t
       LEFT JOIN accounts a ON t.account_id = a.id
       LEFT JOIN users u ON t.created_by = u.id
       WHERE ${conditions.join(' AND ')}
       ORDER BY t.transaction_date DESC, t.created_at DESC
       LIMIT $${idx++} OFFSET $${idx++}`,
      values,
    );

    const [countRes] = await this.dataSource.query(
      `SELECT COUNT(*) as total FROM transactions t WHERE ${conditions.join(' AND ')}`,
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

  async createTransaction(
    dto: {
      accountId: string;
      type: 'INCOME' | 'EXPENSE';
      amount: number | string;
      description?: string;
      category?: string;
      categoryId?: string;
      referenceType?: string;
      referenceId?: string;
    },
    userId?: string,
  ) {
    const queryRunner = this.dataSource.createQueryRunner();
    await queryRunner.connect();
    await queryRunner.startTransaction();

    try {
      const amountDec = new Decimal(dto.amount);
      if (amountDec.lte(0)) {
        throw new BadRequestException('Сумма транзакции должна быть больше 0');
      }

      // Check account exists
      const [acc] = await queryRunner.query(`SELECT * FROM accounts WHERE id = $1`, [dto.accountId]);
      if (!acc) {
        throw new NotFoundException('Счет не найден');
      }

      const category = dto.categoryId || dto.category || null;

      // 1. Insert transaction
      const txRes = await queryRunner.query(
        `INSERT INTO transactions (account_id, type, amount, description, category_id, reference_type, reference_id, created_by)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8) RETURNING *`,
        [
          dto.accountId,
          dto.type,
          amountDec.toFixed(2),
          dto.description || null,
          category,
          dto.referenceType || null,
          dto.referenceId || null,
          userId || null,
        ],
      );

      // 2. Update account balance atomically
      const balanceOperator = dto.type === 'INCOME' ? '+' : '-';
      await queryRunner.query(
        `UPDATE accounts SET balance = balance ${balanceOperator} $1 WHERE id = $2`,
        [amountDec.toFixed(2), dto.accountId],
      );

      // 3. Create audit log
      await queryRunner.query(
        `INSERT INTO audit_logs (user_id, action, entity_name, entity_id, new_values)
         VALUES ($1, $2, 'TRANSACTION', $3, $4)`,
        [userId || null, `CREATE_${dto.type}`, txRes[0].id, JSON.stringify(txRes[0])],
      );

      await queryRunner.commitTransaction();
      return txRes[0];
    } catch (err) {
      await queryRunner.rollbackTransaction();
      throw err;
    } finally {
      await queryRunner.release();
    }
  }

  async createTransfer(
    dto: { fromAccountId: string; toAccountId: string; amount: number | string; description?: string },
    userId?: string,
  ) {
    const queryRunner = this.dataSource.createQueryRunner();
    await queryRunner.connect();
    await queryRunner.startTransaction();

    try {
      const amountDec = new Decimal(dto.amount);
      if (amountDec.lte(0)) throw new BadRequestException('Сумма перевода должна быть больше 0');

      // Check balance
      const [fromAcc] = await queryRunner.query(`SELECT balance FROM accounts WHERE id = $1`, [dto.fromAccountId]);
      if (!fromAcc || new Decimal(fromAcc.balance).lt(amountDec)) {
        throw new BadRequestException('Недостаточно средств на счете списания');
      }

      // Record transaction
      const txRes = await queryRunner.query(
        `INSERT INTO transactions (account_id, to_account_id, type, amount, description, created_by)
         VALUES ($1, $2, 'TRANSFER', $3, $4, $5) RETURNING *`,
        [dto.fromAccountId, dto.toAccountId, amountDec.toFixed(2), dto.description || 'Перевод между счетами', userId || null],
      );

      // Atomic balance updates
      await queryRunner.query(`UPDATE accounts SET balance = balance - $1 WHERE id = $2`, [amountDec.toFixed(2), dto.fromAccountId]);
      await queryRunner.query(`UPDATE accounts SET balance = balance + $1 WHERE id = $2`, [amountDec.toFixed(2), dto.toAccountId]);

      // Audit log
      await queryRunner.query(
        `INSERT INTO audit_logs (user_id, action, entity_name, entity_id, new_values)
         VALUES ($1, 'TRANSFER', 'TRANSACTION', $2, $3)`,
        [userId || null, txRes[0].id, JSON.stringify(txRes[0])],
      );

      await queryRunner.commitTransaction();
      return txRes[0];
    } catch (err) {
      await queryRunner.rollbackTransaction();
      throw err;
    } finally {
      await queryRunner.release();
    }
  }

  async getCashFlow(period?: string) {
    return this.dataSource.query(`
      SELECT 
        transaction_date,
        SUM(CASE WHEN type = 'INCOME' THEN amount ELSE 0 END) AS income,
        SUM(CASE WHEN type = 'EXPENSE' THEN amount ELSE 0 END) AS expense
      FROM transactions
      GROUP BY transaction_date
      ORDER BY transaction_date DESC
      LIMIT 30
    `);
  }

  async getCustomerDebts() {
    return this.dataSource.query(`
      SELECT 
        c.id, c.name, c.phone, c.balance,
        COALESCE(SUM(s.grand_total - s.paid_amount), 0) AS unpaid_sales_total,
        COUNT(s.id) AS unpaid_orders_count
      FROM customers c
      LEFT JOIN sales s ON s.customer_id = c.id AND s.payment_status != 'PAID'
      GROUP BY c.id
      HAVING COALESCE(SUM(s.grand_total - s.paid_amount), 0) > 0 OR c.balance > 0
      ORDER BY unpaid_sales_total DESC
    `);
  }

  async getSupplierDebts() {
    return this.dataSource.query(`
      SELECT 
        sup.id, sup.name, sup.phone, sup.balance,
        COALESCE(SUM(ish.total_amount + ish.additional_costs), 0) AS total_shipments_cost,
        COALESCE((SELECT SUM(amount) FROM payments p WHERE p.supplier_id = sup.id AND p.type = 'OUTGOING'), 0) AS total_paid
      FROM suppliers sup
      LEFT JOIN incoming_shipments ish ON ish.supplier_id = sup.id AND ish.status != 'CANCELLED'
      GROUP BY sup.id
      ORDER BY sup.balance DESC
    `);
  }

  async createSalaryRecord(employeeId: string, amount: number | string, period: string) {
    const amountDec = new Decimal(amount);
    const res = await this.dataSource.query(
      `INSERT INTO salary_records (employee_id, base_salary, net_salary, month_year, status)
       VALUES ($1, $2, $2, $3, 'PAID') RETURNING *`,
      [employeeId, amountDec.toFixed(2), period],
    );
    return res[0];
  }

  async createAdvance(employeeId: string, amount: number | string, reason?: string) {
    const amountDec = new Decimal(amount);
    const res = await this.dataSource.query(
      `INSERT INTO employee_advances (employee_id, amount, status)
       VALUES ($1, $2, 'APPROVED') RETURNING *`,
      [employeeId, amountDec.toFixed(2)],
    );
    return res[0];
  }

  async getPaymentHistory(query: any) {
    return this.dataSource.query(`SELECT * FROM payments ORDER BY payment_date DESC LIMIT 50`);
  }
}
