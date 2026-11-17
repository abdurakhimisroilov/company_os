import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
} from 'typeorm';

export enum SaleStatus {
  COMPLETED = 'COMPLETED',
  DRAFT = 'DRAFT',
  CANCELLED = 'CANCELLED',
  RETURNED = 'RETURNED',
}

export enum PaymentStatus {
  PAID = 'PAID',
  PARTIAL = 'PARTIAL',
  UNPAID = 'UNPAID',
}

@Entity('sales')
export class Sale {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'sale_number', unique: true })
  saleNumber: string;

  @Column({ name: 'customer_id', nullable: true })
  customerId: string;

  @Column({ name: 'warehouse_id', nullable: true })
  warehouseId: string;

  @Column({ default: SaleStatus.COMPLETED })
  status: string;

  @Column({ name: 'payment_status', default: PaymentStatus.UNPAID })
  paymentStatus: string;

  @Column({ type: 'decimal', precision: 20, scale: 2, default: 0.0 })
  subtotal: string;

  @Column({ type: 'decimal', precision: 20, scale: 2, default: 0.0 })
  discount: string;

  @Column({ type: 'decimal', precision: 20, scale: 2, default: 0.0 })
  tax: string;

  @Column({ name: 'grand_total', type: 'decimal', precision: 20, scale: 2, default: 0.0 })
  grandTotal: string;

  @Column({ name: 'paid_amount', type: 'decimal', precision: 20, scale: 2, default: 0.0 })
  paidAmount: string;

  @Column({ name: 'created_by', nullable: true })
  createdBy: string;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;
}
