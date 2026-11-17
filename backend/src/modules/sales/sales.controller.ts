import { Controller, Get, Post, Body, Param, Query, UseGuards, Req } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { SalesService } from './sales.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';

@ApiTags('Sales')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('sales')
export class SalesController {
  constructor(private readonly salesService: SalesService) {}

  @Get()
  @ApiOperation({ summary: 'Get sales list with filters' })
  async getSales(@Query() query: any) {
    return this.salesService.getSales(query);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get sale details with items and payments' })
  async getSaleById(@Param('id') id: string) {
    return this.salesService.getSaleById(id);
  }

  @Post()
  @ApiOperation({ summary: 'Create new sale (updates stock, financial transactions)' })
  async createSale(@Body() dto: any, @Req() req: any) {
    return this.salesService.createSale(dto, req.user?.id);
  }

  @Post(':id/payments')
  @ApiOperation({ summary: 'Process payment for a sale' })
  async processPayment(@Param('id') id: string, @Body() dto: any, @Req() req: any) {
    return this.salesService.processPayment(id, dto, req.user?.id);
  }

  @Post(':id/returns')
  @ApiOperation({ summary: 'Create sale return' })
  async createReturn(@Param('id') id: string, @Body() dto: any, @Req() req: any) {
    return this.salesService.createReturn(id, dto, req.user?.id);
  }
}
