import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { InventoryController } from './inventory.controller';
import { InventoryService } from './inventory.service';
import { Product } from './entities/product.entity';
import { ProductCategory } from './entities/product_category.entity';
import { Inventory } from './entities/inventory.entity';
import { StockMovement } from './entities/stock_movement.entity';

@Module({
  imports: [TypeOrmModule.forFeature([Product, ProductCategory, Inventory, StockMovement])],
  controllers: [InventoryController],
  providers: [InventoryService],
  exports: [InventoryService],
})
export class InventoryModule {}
