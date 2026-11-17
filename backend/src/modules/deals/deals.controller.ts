import { Controller, Get, Post, Put, Body, Param, Query, UseGuards, Req } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { DealsService } from './deals.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';

@ApiTags('Deals')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('deals')
export class DealsController {
  constructor(private readonly dealsService: DealsService) {}

  @Get()
  @ApiOperation({ summary: 'Get deals list with filters' })
  async getDeals(@Query() query: any) {
    return this.dealsService.getDeals(query);
  }

  @Get('kanban')
  @ApiOperation({ summary: 'Get deals grouped by status for Kanban board' })
  async getKanban() {
    return this.dealsService.getKanbanBoard();
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get deal details with activities and comments' })
  async getDealById(@Param('id') id: string) {
    return this.dealsService.getDealById(id);
  }

  @Post()
  @ApiOperation({ summary: 'Create new deal' })
  async createDeal(@Body() dto: any, @Req() req: any) {
    return this.dealsService.createDeal(dto, req.user?.id);
  }

  @Put(':id')
  @ApiOperation({ summary: 'Update deal' })
  async updateDeal(@Param('id') id: string, @Body() dto: any, @Req() req: any) {
    return this.dealsService.updateDeal(id, dto, req.user?.id);
  }

  @Put(':id/status')
  @ApiOperation({ summary: 'Update deal status (logs timeline activity)' })
  async updateStatus(@Param('id') id: string, @Body('status') status: string, @Req() req: any) {
    return this.dealsService.updateStatus(id, status, req.user?.id);
  }

  @Post(':id/comments')
  @ApiOperation({ summary: 'Add comment to deal' })
  async addComment(@Param('id') id: string, @Body('content') content: string, @Req() req: any) {
    return this.dealsService.addComment(id, content, req.user?.id);
  }
}
