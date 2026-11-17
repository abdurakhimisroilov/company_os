import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
} from 'typeorm';

@Entity('sale_items')
export class SaleItem {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'sale_id' })
  saleId: string;

  @Column({ name: 'product_id' })
  productId: string;

  @Column({ type: 'decimal', precision: 20, scale: 2 })
  quantity: string;

  @Column({ name: 'unit_price', type: 'decimal', precision: 20, scale: 2 })
  unitPrice: string;

  @Column({ name: 'cost_price', type: 'decimal', precision: 20, scale: 2, default: 0.0 })
  costPrice: string;

  @Column({ type: 'decimal', precision: 20, scale: 2, default: 0.0 })
  discount: string;

  @Column({ name: 'total_amount', type: 'decimal', precision: 20, scale: 2 })
  totalAmount: string;
}
