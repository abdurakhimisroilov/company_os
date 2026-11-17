import { Controller, Get, Post, Put, Body, Param, Query, UseGuards, Req } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { TasksService } from './tasks.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';

@ApiTags('Tasks')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('tasks')
export class TasksController {
  constructor(private readonly tasksService: TasksService) {}

  @Get()
  @ApiOperation({ summary: 'Get tasks with filtering' })
  async getTasks(@Query() query: any, @Req() req: any) {
    return this.tasksService.getTasks(query, req.user?.id);
  }

  @Get('overdue')
  @ApiOperation({ summary: 'Get overdue tasks' })
  async getOverdueTasks() {
    return this.tasksService.getOverdueTasks();
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get task by ID' })
  async getTaskById(@Param('id') id: string) {
    return this.tasksService.getTaskById(id);
  }

  @Post()
  @ApiOperation({ summary: 'Create new task' })
  async createTask(@Body() dto: any, @Req() req: any) {
    return this.tasksService.createTask(dto, req.user?.id);
  }

  @Put(':id/status')
  @ApiOperation({ summary: 'Update task status and progress' })
  async updateStatus(
    @Param('id') id: string,
    @Body('status') status: string,
    @Body('progress') progress: number,
    @Req() req: any,
  ) {
    return this.tasksService.updateStatus(id, status, progress, req.user?.id);
  }

  @Post(':id/approve')
  @ApiOperation({ summary: 'Approve task (managers only)' })
  async approveTask(@Param('id') id: string, @Req() req: any) {
    return this.tasksService.approveTask(id, req.user?.role, req.user?.id);
  }

  @Post(':id/return')
  @ApiOperation({ summary: 'Return task for revision (managers only)' })
  async returnTask(@Param('id') id: string, @Body('reason') reason: string, @Req() req: any) {
    return this.tasksService.returnTask(id, reason, req.user?.role, req.user?.id);
  }

  @Post(':id/comments')
  @ApiOperation({ summary: 'Add comment to task' })
  async addComment(@Param('id') id: string, @Body('content') content: string, @Req() req: any) {
    return this.tasksService.addComment(id, content, req.user?.id);
  }

  @Post(':id/attachments')
  @ApiOperation({ summary: 'Upload attachment to task' })
  async uploadAttachment(@Param('id') id: string, @Body() file: any, @Req() req: any) {
    return this.tasksService.uploadAttachment(id, file, req.user?.id);
  }
}
