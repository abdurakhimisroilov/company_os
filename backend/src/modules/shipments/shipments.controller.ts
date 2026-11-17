import { Controller, Get, Post, Body, Param, Query, UseGuards, Req } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { ShipmentsService } from './shipments.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';

@ApiTags('Shipments')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('shipments')
export class ShipmentsController {
  constructor(private readonly shipmentsService: ShipmentsService) {}

  @Get()
  @ApiOperation({ summary: 'Get incoming shipments with filters' })
  async getShipments(@Query() query: any) {
    return this.shipmentsService.getShipments(query);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get shipment details' })
  async getShipmentById(@Param('id') id: string) {
    return this.shipmentsService.getShipmentById(id);
  }

  @Post()
  @ApiOperation({ summary: 'Create incoming shipment' })
  async createShipment(@Body() dto: any, @Req() req: any) {
    return this.shipmentsService.createShipment(dto, req.user?.id);
  }

  @Post(':id/confirm')
  @ApiOperation({ summary: 'Confirm receipt of goods (updates stock and finances)' })
  async confirmReceipt(@Param('id') id: string, @Req() req: any) {
    return this.shipmentsService.confirmReceipt(id, req.user?.id);
  }
}
