import { Injectable } from '@nestjs/common';
import { DataSource } from 'typeorm';
import * as ExcelJS from 'exceljs';
import * as PDFDocument from 'pdfkit';
import Decimal from 'decimal.js';

@Injectable()
export class ReportsService {
  constructor(private readonly dataSource: DataSource) {}

  async generateFinancialReport(startDate?: string, endDate?: string) {
    const conditions: string[] = ['1=1'];
    const values: any[] = [];
    let idx = 1;

    if (startDate) {
      conditions.push(`t.transaction_date >= $${idx++}`);
      values.push(startDate);
    }
    if (endDate) {
      conditions.push(`t.transaction_date <= $${idx++}`);
      values.push(endDate);
    }

    const summary = await this.dataSource.query(
      `SELECT 
        t.type,
        COALESCE(c.name, 'Без категории') AS category_name,
        SUM(t.amount) AS total_amount
       FROM transactions t
       LEFT JOIN expense_categories c ON t.category_id = c.id
       WHERE ${conditions.join(' AND ')}
       GROUP BY t.type, c.name
       ORDER BY total_amount DESC`,
      values,
    );

    let totalIncome = new Decimal(0);
    let totalExpense = new Decimal(0);

    for (const row of summary) {
      if (row.type === 'INCOME') totalIncome = totalIncome.plus(row.total_amount);
      if (row.type === 'EXPENSE') totalExpense = totalExpense.plus(row.total_amount);
    }

    return {
      period: { startDate, endDate },
      totalIncome: totalIncome.toNumber(),
      totalExpense: totalExpense.toNumber(),
      netProfit: totalIncome.minus(totalExpense).toNumber(),
      breakdown: summary,
    };
  }

  async generateSalesReport(startDate?: string, endDate?: string) {
    const conditions: string[] = ["s.status != 'CANCELLED'"];
    const values: any[] = [];
    let idx = 1;

    if (startDate) {
      conditions.push(`s.created_at >= $${idx++}`);
      values.push(startDate);
    }
    if (endDate) {
      conditions.push(`s.created_at <= $${idx++}`);
      values.push(endDate);
    }

    const byProduct = await this.dataSource.query(
      `SELECT 
        p.name AS product_name,
        p.sku,
        SUM(si.quantity) AS total_quantity,
        SUM(si.total_amount) AS total_revenue
       FROM sale_items si
       JOIN products p ON si.product_id = p.id
       JOIN sales s ON si.sale_id = s.id
       WHERE ${conditions.join(' AND ')}
       GROUP BY p.name, p.sku
       ORDER BY total_revenue DESC`,
      values,
    );

    const byCustomer = await this.dataSource.query(
      `SELECT 
        COALESCE(c.name, 'Розничный покупатель') AS customer_name,
        COUNT(s.id) AS orders_count,
        SUM(s.grand_total) AS total_revenue
       FROM sales s
       LEFT JOIN customers c ON s.customer_id = c.id
       WHERE ${conditions.join(' AND ')}
       GROUP BY c.name
       ORDER BY total_revenue DESC`,
      values,
    );

    const byEmployee = await this.dataSource.query(
      `SELECT 
        u.full_name AS employee_name,
        COUNT(s.id) AS sales_count,
        SUM(s.grand_total) AS total_sales
       FROM sales s
       LEFT JOIN users u ON s.created_by = u.id
       WHERE ${conditions.join(' AND ')}
       GROUP BY u.full_name
       ORDER BY total_sales DESC`,
      values,
    );

    return { byProduct, byCustomer, byEmployee };
  }

  async generateInventoryReport() {
    const inventory = await this.dataSource.query(`
      SELECT 
        p.name, p.sku, p.unit, p.selling_price, p.min_stock_level,
        COALESCE(i.quantity, 0) AS quantity,
        COALESCE(i.average_cost, 0) AS average_cost,
        (COALESCE(i.quantity, 0) * COALESCE(i.average_cost, 0)) AS total_cost
      FROM products p
      LEFT JOIN inventory i ON p.id = i.product_id
      WHERE p.is_active = true
      ORDER BY total_cost DESC
    `);

    const lowStock = inventory.filter((item: any) => parseFloat(item.quantity) <= item.min_stock_level);
    const totalValuation = inventory.reduce((sum: number, item: any) => sum + parseFloat(item.total_cost || '0'), 0);

    return {
      totalValuation,
      totalItems: inventory.length,
      lowStockCount: lowStock.length,
      inventory,
      lowStock,
    };
  }

  async generatePLReport(startDate?: string, endDate?: string) {
    const conditions: string[] = ["s.status != 'CANCELLED'"];
    const values: any[] = [];
    let idx = 1;

    if (startDate) {
      conditions.push(`s.created_at >= $${idx++}`);
      values.push(startDate);
    }
    if (endDate) {
      conditions.push(`s.created_at <= $${idx++}`);
      values.push(endDate);
    }

    // Revenue and COGS
    const [rev] = await this.dataSource.query(
      `SELECT 
        COALESCE(SUM(s.grand_total), 0) AS revenue,
        COALESCE((SELECT SUM(si.cost_price * si.quantity) FROM sale_items si JOIN sales s2 ON si.sale_id = s2.id WHERE ${conditions.join(' AND ')}), 0) AS cogs
       FROM sales s
       WHERE ${conditions.join(' AND ')}`,
      values,
    );

    const revenue = new Decimal(rev?.revenue || 0);
    const cogs = new Decimal(rev?.cogs || 0);
    const grossProfit = revenue.minus(cogs);

    // Operating expenses from transactions
    const expConditions: string[] = ["t.type = 'EXPENSE'"];
    const expValues: any[] = [];
    let expIdx = 1;
    if (startDate) {
      expConditions.push(`t.transaction_date >= $${expIdx++}`);
      expValues.push(startDate);
    }
    if (endDate) {
      expConditions.push(`t.transaction_date <= $${expIdx++}`);
      expValues.push(endDate);
    }

    const [exp] = await this.dataSource.query(
      `SELECT COALESCE(SUM(amount), 0) AS total_expense FROM transactions t WHERE ${expConditions.join(' AND ')}`,
      expValues,
    );

    const operatingExpenses = new Decimal(exp?.total_expense || 0);
    const netProfit = grossProfit.minus(operatingExpenses);

    return {
      period: { startDate, endDate },
      revenue: revenue.toNumber(),
      cogs: cogs.toNumber(),
      grossProfit: grossProfit.toNumber(),
      operatingExpenses: operatingExpenses.toNumber(),
      netProfit: netProfit.toNumber(),
    };
  }

  async exportToPDF(startDate?: string, endDate?: string): Promise<Buffer> {
    return new Promise(async (resolve) => {
      const doc = new PDFDocument({ margin: 40 });
      const buffers: Buffer[] = [];

      doc.on('data', buffers.push.bind(buffers));
      doc.on('end', () => resolve(Buffer.concat(buffers)));

      doc.fontSize(20).text('COMPANY OS - Financial & PL Report', { align: 'center' });
      doc.moveDown();
      doc.fontSize(12).text(`Generated at: ${new Date().toLocaleString()}`);
      doc.text(`Period: ${startDate || 'All'} - ${endDate || 'All'}`);
      doc.moveDown();

      const pl = await this.generatePLReport(startDate, endDate);
      doc.fontSize(14).text('Profit & Loss Summary:');
      doc.fontSize(11).text(`Revenue: ${pl.revenue.toLocaleString()} UZS`);
      doc.text(`COGS: ${pl.cogs.toLocaleString()} UZS`);
      doc.text(`Gross Profit: ${pl.grossProfit.toLocaleString()} UZS`);
      doc.text(`Operating Expenses: ${pl.operatingExpenses.toLocaleString()} UZS`);
      doc.text(`Net Profit: ${pl.netProfit.toLocaleString()} UZS`);
      doc.end();
    });
  }

  async exportToExcel(startDate?: string, endDate?: string): Promise<Buffer> {
    const workbook = new ExcelJS.Workbook();
    const sheet = workbook.addWorksheet('Sales Report');

    sheet.columns = [
      { header: 'Product', key: 'product_name', width: 30 },
      { header: 'SKU', key: 'sku', width: 15 },
      { header: 'Quantity Sold', key: 'total_quantity', width: 15 },
      { header: 'Revenue (UZS)', key: 'total_revenue', width: 20 },
    ];

    const sales = await this.generateSalesReport(startDate, endDate);
    for (const item of sales.byProduct) {
      sheet.addRow(item);
    }

    const uint8Array = await workbook.xlsx.writeBuffer();
    return Buffer.from(uint8Array);
  }
}
