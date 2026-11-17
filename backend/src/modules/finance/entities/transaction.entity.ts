import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
} from 'typeorm';

export enum TransactionType {
  INCOME = 'INCOME',
  EXPENSE = 'EXPENSE',
  TRANSFER = 'TRANSFER',
}

@Entity('transactions')
export class Transaction {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'varchar' })
  type: TransactionType;

  @Column({ name: 'account_id' })
  accountId: string;

  @Column({ name: 'to_account_id', nullable: true })
  toAccountId: string;

  @Column({ name: 'category_id', nullable: true })
  categoryId: string;

  @Column({ type: 'decimal', precision: 20, scale: 2 })
  amount: string;

  @Column({ nullable: true })
  description: string;

  @Column({ name: 'reference_type', nullable: true })
  referenceType: string;

  @Column({ name: 'reference_id', nullable: true })
  referenceId: string;

  @Column({ name: 'created_by', nullable: true })
  createdBy: string;

  @Column({ name: 'transaction_date', type: 'date', default: () => 'CURRENT_DATE' })
  transactionDate: string;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;
}
