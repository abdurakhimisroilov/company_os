import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
} from 'typeorm';

export enum AccountType {
  CASH = 'CASH',
  BANK = 'BANK',
  CARD = 'CARD',
}

@Entity('accounts')
export class Account {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  name: string;

  @Column({ type: 'varchar', default: AccountType.CASH })
  type: AccountType;

  @Column({ name: 'account_number', nullable: true })
  accountNumber: string;

  @Column({ type: 'decimal', precision: 20, scale: 2, default: 0.0 })
  balance: string;

  @Column({ default: 'UZS' })
  currency: string;

  @Column({ name: 'is_active', default: true })
  isActive: boolean;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;
}
