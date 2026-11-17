import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
} from 'typeorm';

export enum DealStatus {
  NEW = 'NEW',
  CONTACT = 'CONTACT',
  NEGOTIATION = 'NEGOTIATION',
  PROPOSAL_SENT = 'PROPOSAL_SENT',
  AWAITING_PAYMENT = 'AWAITING_PAYMENT',
  WON = 'WON',
  LOST = 'LOST',
}

@Entity('deals')
export class Deal {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  title: string;

  @Column({ name: 'customer_id', nullable: true })
  customerId: string;

  @Column({ type: 'decimal', precision: 20, scale: 2, default: 0.0 })
  amount: string;

  @Column({ default: DealStatus.NEW })
  status: string;

  @Column({ name: 'expected_close_date', type: 'date', nullable: true })
  expectedCloseDate: string;

  @Column({ name: 'assigned_to', nullable: true })
  assignedTo: string;

  @Column({ nullable: true })
  description: string;

  @Column({ name: 'created_by', nullable: true })
  createdBy: string;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;
}
