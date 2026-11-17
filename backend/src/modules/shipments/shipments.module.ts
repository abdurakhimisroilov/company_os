import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ShipmentsController } from './shipments.controller';
import { ShipmentsService } from './shipments.service';
import { IncomingShipment } from './entities/incoming_shipment.entity';
import { IncomingShipmentItem } from './entities/incoming_shipment_item.entity';
import { ShipmentCost } from './entities/shipment_cost.entity';

@Module({
  imports: [TypeOrmModule.forFeature([IncomingShipment, IncomingShipmentItem, ShipmentCost])],
  controllers: [ShipmentsController],
  providers: [ShipmentsService],
  exports: [ShipmentsService],
})
export class ShipmentsModule {}
