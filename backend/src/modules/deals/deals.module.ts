import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { DealsController } from './deals.controller';
import { DealsService } from './deals.service';
import { Deal } from './entities/deal.entity';
import { DealActivity } from './entities/deal_activity.entity';
import { DealComment } from './entities/deal_comment.entity';

@Module({
  imports: [TypeOrmModule.forFeature([Deal, DealActivity, DealComment])],
  controllers: [DealsController],
  providers: [DealsService],
  exports: [DealsService],
})
export class DealsModule {}
