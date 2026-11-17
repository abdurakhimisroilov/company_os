import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { TasksController } from './tasks.controller';
import { TasksService } from './tasks.service';
import { Task } from './entities/task.entity';
import { TaskComment } from './entities/task_comment.entity';
import { TaskAttachment } from './entities/task_attachment.entity';

@Module({
  imports: [TypeOrmModule.forFeature([Task, TaskComment, TaskAttachment])],
  controllers: [TasksController],
  providers: [TasksService],
  exports: [TasksService],
})
export class TasksModule {}
