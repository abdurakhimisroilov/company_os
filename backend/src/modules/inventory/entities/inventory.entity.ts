import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  UpdateDateColumn,
} from 'typeorm';

@Entity('inventory')
export class Inventory {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'product_id' })
  productId: string;

  @Column({ name: 'warehouse_id' })
  warehouseId: string;

  @Column({ type: 'decimal', precision: 20, scale: 2, default: 0.0 })
  quantity: string;

  @Column({ name: 'reserved_quantity', type: 'decimal', precision: 20, scale: 2, default: 0.0 })
  reservedQuantity: string;

  @Column({ name: 'average_cost', type: 'decimal', precision: 20, scale: 2, default: 0.0 })
  averageCost: string;

  @UpdateDateColumn({ name: 'last_updated_at' })
  lastUpdatedAt: Date;
}
