import { Controller, Get, Post, Body, Param, Query, UseGuards, Req } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { ChatService } from './chat.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';

@ApiTags('Chat')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('chat')
export class ChatController {
  constructor(private readonly chatService: ChatService) {}

  @Get('rooms')
  @ApiOperation({ summary: 'Get all chat rooms for current user' })
  async getRooms(@Req() req: any) {
    return this.chatService.getRooms(req.user?.id);
  }

  @Post('rooms')
  @ApiOperation({ summary: 'Create new chat room' })
  async createRoom(@Body() dto: any, @Req() req: any) {
    return this.chatService.createRoom(dto, req.user?.id);
  }

  @Get('rooms/:id/messages')
  @ApiOperation({ summary: 'Get messages for a room' })
  async getMessages(@Param('id') roomId: string, @Query() query: any, @Req() req: any) {
    return this.chatService.getMessages(roomId, req.user?.id, query);
  }

  @Post('rooms/:id/messages')
  @ApiOperation({ summary: 'Send message via REST fallback' })
  async sendMessage(@Param('id') roomId: string, @Body() dto: any, @Req() req: any) {
    return this.chatService.sendMessage({ ...dto, roomId }, req.user?.id);
  }

  @Post('rooms/:id/read')
  @ApiOperation({ summary: 'Mark room messages as read' })
  async markRead(@Param('id') roomId: string, @Req() req: any) {
    return this.chatService.markAsRead(roomId, req.user?.id);
  }
}
