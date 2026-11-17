import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
} from 'typeorm';

@Entity('products')
export class Product {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  name: string;

  @Column({ unique: true })
  sku: string;

  @Column({ nullable: true })
  barcode: string;

  @Column({ name: 'category_id', nullable: true })
  categoryId: string;

  @Column({ default: 'шт' })
  unit: string;

  @Column({ name: 'purchase_price', type: 'decimal', precision: 20, scale: 2, default: 0.0 })
  purchasePrice: string;

  @Column({ name: 'selling_price', type: 'decimal', precision: 20, scale: 2, default: 0.0 })
  sellingPrice: string;

  @Column({ name: 'min_stock_level', default: 5 })
  minStockLevel: number;

  @Column({ nullable: true })
  description: string;

  @Column({ name: 'image_url', nullable: true })
  imageUrl: string;

  @Column({ name: 'is_active', default: true })
  isActive: boolean;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;
}
