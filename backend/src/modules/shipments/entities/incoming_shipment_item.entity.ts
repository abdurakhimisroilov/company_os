import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
} from 'typeorm';

@Entity('incoming_shipment_items')
export class IncomingShipmentItem {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'shipment_id' })
  shipmentId: string;

  @Column({ name: 'product_id' })
  productId: string;

  @Column({ type: 'decimal', precision: 20, scale: 2 })
  quantity: string;

  @Column({ name: 'received_quantity', type: 'decimal', precision: 20, scale: 2, default: 0.0 })
  receivedQuantity: string;

  @Column({ name: 'purchase_price', type: 'decimal', precision: 20, scale: 2 })
  purchasePrice: string;

  @Column({ name: 'total_amount', type: 'decimal', precision: 20, scale: 2 })
  totalAmount: string;
}
