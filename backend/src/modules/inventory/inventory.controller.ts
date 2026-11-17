import { Controller, Get, Post, Put, Body, Param, Query, UseGuards, Req } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { InventoryService } from './inventory.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';

@ApiTags('Inventory')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('inventory')
export class InventoryController {
  constructor(private readonly inventoryService: InventoryService) {}

  @Get('products')
  @ApiOperation({ summary: 'Get products list with stock levels' })
  async getProducts(@Query() query: any) {
    return this.inventoryService.getProducts(query);
  }

  @Get('products/:id')
  @ApiOperation({ summary: 'Get product detail with movements' })
  async getProductById(@Param('id') id: string) {
    return this.inventoryService.getProductById(id);
  }

  @Post('products')
  @ApiOperation({ summary: 'Create new product' })
  async createProduct(@Body() dto: any, @Req() req: any) {
    return this.inventoryService.createProduct(dto, req.user?.id);
  }

  @Put('products/:id')
  @ApiOperation({ summary: 'Update product' })
  async updateProduct(@Param('id') id: string, @Body() dto: any, @Req() req: any) {
    return this.inventoryService.updateProduct(id, dto, req.user?.id);
  }

  @Post('adjust')
  @ApiOperation({ summary: 'Manual stock adjustment' })
  async adjustStock(@Body() dto: any, @Req() req: any) {
    return this.inventoryService.adjustStock(dto, req.user?.id);
  }

  @Get('low-stock')
  @ApiOperation({ summary: 'Get low stock products' })
  async getLowStock() {
    return this.inventoryService.getLowStockProducts();
  }

  @Get('value')
  @ApiOperation({ summary: 'Get inventory valuation' })
  async getInventoryValue() {
    return this.inventoryService.getInventoryValue();
  }

  @Get('products/:id/movements')
  @ApiOperation({ summary: 'Get stock movements for a product' })
  async getStockMovements(@Param('id') id: string, @Query() query: any) {
    return this.inventoryService.getStockMovements(id, query);
  }
}
