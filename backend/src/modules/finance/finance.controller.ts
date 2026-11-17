import { Controller, Get, Post, Body, Param, Query, UseGuards, Req } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { FinanceService } from './finance.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';

@ApiTags('Finance')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('finance')
export class FinanceController {
  constructor(private readonly financeService: FinanceService) {}

  @Get('accounts')
  @ApiOperation({ summary: 'Get all accounts' })
  async getAccounts() {
    return this.financeService.getAccounts();
  }

  @Post('accounts')
  @ApiOperation({ summary: 'Create account' })
  async createAccount(@Body() dto: any) {
    return this.financeService.createAccount(dto);
  }

  @Get('transactions')
  @ApiOperation({ summary: 'Get transactions with filters' })
  async getTransactions(@Query() query: any) {
    return this.financeService.getTransactions(query);
  }

  @Post('transactions/income')
  @ApiOperation({ summary: 'Create income transaction' })
  async createIncome(@Body() dto: any, @Req() req: any) {
    return this.financeService.createTransaction({ ...dto, type: 'INCOME' }, req.user?.id);
  }

  @Post('transactions/expense')
  @ApiOperation({ summary: 'Create expense transaction' })
  async createExpense(@Body() dto: any, @Req() req: any) {
    return this.financeService.createTransaction({ ...dto, type: 'EXPENSE' }, req.user?.id);
  }

  @Post('transactions/transfer')
  @ApiOperation({ summary: 'Transfer between accounts' })
  async createTransfer(@Body() dto: any, @Req() req: any) {
    return this.financeService.createTransfer(dto, req.user?.id);
  }

  @Get('cash-flow')
  @ApiOperation({ summary: 'Get cash flow analysis' })
  async getCashFlow(@Query('period') period?: string) {
    return this.financeService.getCashFlow(period);
  }

  @Get('customer-debts')
  @ApiOperation({ summary: 'Get customer debt summary' })
  async getCustomerDebts() {
    return this.financeService.getCustomerDebts();
  }

  @Get('supplier-debts')
  @ApiOperation({ summary: 'Get supplier debt summary' })
  async getSupplierDebts() {
    return this.financeService.getSupplierDebts();
  }

  @Post('salary')
  @ApiOperation({ summary: 'Create salary payment record' })
  async createSalary(@Body() dto: { employeeId: string; amount: number; period: string }) {
    return this.financeService.createSalaryRecord(dto.employeeId, dto.amount, dto.period);
  }

  @Post('advances')
  @ApiOperation({ summary: 'Create employee advance' })
  async createAdvance(@Body() dto: { employeeId: string; amount: number; reason?: string }) {
    return this.financeService.createAdvance(dto.employeeId, dto.amount, dto.reason);
  }

  @Get('payments')
  @ApiOperation({ summary: 'Get payments history' })
  async getPaymentHistory(@Query() query: any) {
    return this.financeService.getPaymentHistory(query);
  }
}
