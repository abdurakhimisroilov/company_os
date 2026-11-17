import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
} from 'typeorm';

export enum ShipmentStatus {
  PENDING = 'PENDING',
  RECEIVED = 'RECEIVED',
  PARTIAL = 'PARTIAL',
  CANCELLED = 'CANCELLED',
}

@Entity('incoming_shipments')
export class IncomingShipment {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'shipment_number', unique: true })
  shipmentNumber: string;

  @Column({ name: 'supplier_id', nullable: true })
  supplierId: string;

  @Column({ name: 'warehouse_id', nullable: true })
  warehouseId: string;

  @Column({ default: ShipmentStatus.PENDING })
  status: string;

  @Column({ name: 'expected_date', type: 'date', nullable: true })
  expectedDate: string;

  @Column({ name: 'received_date', nullable: true })
  receivedDate: Date;

  @Column({ name: 'total_amount', type: 'decimal', precision: 20, scale: 2, default: 0.0 })
  totalAmount: string;

  @Column({ name: 'additional_costs', type: 'decimal', precision: 20, scale: 2, default: 0.0 })
  additionalCosts: string;

  @Column({ nullable: true })
  notes: string;

  @Column({ name: 'created_by', nullable: true })
  createdBy: string;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;
}
