import { Injectable } from '@nestjs/common';
import { DataSource } from 'typeorm';
import Decimal from 'decimal.js';

@Injectable()
export class DashboardService {
  constructor(private readonly dataSource: DataSource) {}

  async getAggregatedStats(period: string = 'month', startDate?: string, endDate?: string, currentUser?: any) {
    let dateFilter = '1=1';
    let txDateFilter = '1=1';
    const now = new Date();

    if (period === 'today') {
      dateFilter = `DATE(created_at) = CURRENT_DATE`;
      txDateFilter = `transaction_date = CURRENT_DATE`;
    } else if (period === 'week') {
      dateFilter = `created_at >= NOW() - INTERVAL '7 days'`;
      txDateFilter = `transaction_date >= CURRENT_DATE - INTERVAL '7 days'`;
    } else if (period === 'month') {
      dateFilter = `created_at >= NOW() - INTERVAL '30 days'`;
      txDateFilter = `transaction_date >= CURRENT_DATE - INTERVAL '30 days'`;
    } else if (period === 'year') {
      dateFilter = `created_at >= NOW() - INTERVAL '1 year'`;
      txDateFilter = `transaction_date >= CURRENT_DATE - INTERVAL '1 year'`;
    } else if (startDate && endDate) {
      dateFilter = `created_at >= '${startDate}' AND created_at <= '${endDate}'`;
      txDateFilter = `transaction_date >= '${startDate}' AND transaction_date <= '${endDate}'`;
    }

    // 1. Account balances
    const balanceRes = await this.dataSource.query(
      `SELECT COALESCE(SUM(balance), 0) AS total_balance FROM accounts WHERE is_active = true`,
    );
    const totalBalance = parseFloat(balanceRes[0]?.total_balance || '0');

    // 2. Total Income & Expenses for period
    const txRes = await this.dataSource.query(
      `SELECT 
         COALESCE(SUM(CASE WHEN type = 'INCOME' THEN amount ELSE 0 END), 0) AS total_income,
         COALESCE(SUM(CASE WHEN type = 'EXPENSE' THEN amount ELSE 0 END), 0) AS total_expenses
       FROM transactions
       WHERE ${txDateFilter}`,
    );
    const totalIncome = parseFloat(txRes[0]?.total_income || '0');
    const totalExpenses = parseFloat(txRes[0]?.total_expenses || '0');
    const netProfit = totalIncome - totalExpenses;

    // 3. Sales total for period
    const salesRes = await this.dataSource.query(
      `SELECT COALESCE(SUM(grand_total), 0) AS total_sales FROM sales WHERE status != 'CANCELLED' AND ${dateFilter}`,
    );
    const totalSales = parseFloat(salesRes[0]?.total_sales || '0');

    // 4. Inventory value & product count
    const stockRes = await this.dataSource.query(
      `SELECT 
         COALESCE(SUM(i.quantity * i.average_cost), 0) AS stock_value,
         COUNT(DISTINCT p.id) AS total_products
       FROM products p
       LEFT JOIN inventory i ON p.id = i.product_id
       WHERE p.is_active = true`,
    );
    const inventoryValue = parseFloat(stockRes[0]?.stock_value || '0');
    const totalProducts = parseInt(stockRes[0]?.total_products || '0', 10);

    // 5. Customer Debts & Supplier Debts
    const customerDebtsRes = await this.dataSource.query(
      `SELECT COALESCE(SUM(grand_total - paid_amount), 0) AS total_debts FROM sales WHERE payment_status != 'PAID'`,
    );
    const supplierDebtsRes = await this.dataSource.query(
      `SELECT COALESCE(SUM(balance), 0) AS supplier_debts FROM suppliers`,
    );
    const customerDebts = parseFloat(customerDebtsRes[0]?.total_debts || '0');
    const supplierDebts = parseFloat(supplierDebtsRes[0]?.supplier_debts || '0');

    // 6. Active Deals
    const dealRes = await this.dataSource.query(
      `SELECT COUNT(*) AS active_deals FROM deals WHERE status NOT IN ('WON', 'LOST')`,
    );
    const activeDeals = parseInt(dealRes[0]?.active_deals || '0', 10);

    // 7. Pending Tasks (filtered for current user or all if manager/admin)
    let taskQuery = `SELECT COUNT(*) AS pending_tasks FROM tasks WHERE status != 'DONE'`;
    if (currentUser && !['SUPER_ADMIN', 'ADMIN'].includes(currentUser.role)) {
      taskQuery += ` AND (assigned_to = '${currentUser.id}' OR created_by = '${currentUser.id}')`;
    }
    const taskRes = await this.dataSource.query(taskQuery);
    const pendingTasks = parseInt(taskRes[0]?.pending_tasks || '0', 10);

    // 8. Monthly Financials (last 12 months)
    const monthlyFinancials = await this.dataSource.query(`
      SELECT 
        TO_CHAR(transaction_date, 'YYYY-MM') AS month,
        COALESCE(SUM(CASE WHEN type = 'INCOME' THEN amount ELSE 0 END), 0) AS income,
        COALESCE(SUM(CASE WHEN type = 'EXPENSE' THEN amount ELSE 0 END), 0) AS expense
      FROM transactions
      WHERE transaction_date >= CURRENT_DATE - INTERVAL '12 months'
      GROUP BY TO_CHAR(transaction_date, 'YYYY-MM')
      ORDER BY month ASC
    `);

    // 9. Recent Transactions (last 10)
    const recentTransactions = await this.dataSource.query(`
      SELECT t.*, a.name AS account_name, u.full_name AS created_by_name
      FROM transactions t
      LEFT JOIN accounts a ON t.account_id = a.id
      LEFT JOIN users u ON t.created_by = u.id
      ORDER BY t.created_at DESC
      LIMIT 10
    `);

    // 10. Recent Activities (last 10 audit logs)
    const recentActivities = await this.dataSource.query(`
      SELECT a.*, u.full_name AS user_name
      FROM audit_logs a
      LEFT JOIN users u ON a.user_id = u.id
      ORDER BY a.created_at DESC
      LIMIT 10
    `);

    // 11. Upcoming Deadlines (next 7 days)
    const upcomingDeadlines = await this.dataSource.query(`
      SELECT 'TASK' AS type, id, title, due_date AS deadline, status
      FROM tasks
      WHERE due_date >= NOW() AND due_date <= NOW() + INTERVAL '7 days' AND status != 'DONE'
      UNION ALL
      SELECT 'DEAL' AS type, id, title, expected_close_date::timestamp AS deadline, status
      FROM deals
      WHERE expected_close_date >= CURRENT_DATE AND expected_close_date <= CURRENT_DATE + INTERVAL '7 days' AND status NOT IN ('WON', 'LOST')
      ORDER BY deadline ASC
      LIMIT 10
    `);

    return {
      period,
      totalBalance,
      totalIncome,
      totalExpenses,
      netProfit,
      totalSales,
      inventoryValue,
      totalProducts,
      activeDeals,
      pendingTasks,
      customerDebts,
      supplierDebts,
      monthlyFinancials,
      recentTransactions,
      recentActivities,
      upcomingDeadlines,
    };
  }
}
