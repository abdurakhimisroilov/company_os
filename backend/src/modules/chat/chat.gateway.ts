import {
  WebSocketGateway,
  WebSocketServer,
  SubscribeMessage,
  OnGatewayConnection,
  OnGatewayDisconnect,
  MessageBody,
  ConnectedSocket,
} from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
import { JwtService } from '@nestjs/jwt';
import { ChatService } from './chat.service';

@WebSocketGateway({
  cors: {
    origin: '*',
  },
})
export class ChatGateway implements OnGatewayConnection, OnGatewayDisconnect {
  @WebSocketServer()
  server: Server;

  constructor(
    private readonly chatService: ChatService,
    private readonly jwtService: JwtService,
  ) {}

  async handleConnection(client: Socket) {
    try {
      const token =
        client.handshake.auth?.token || client.handshake.headers?.authorization?.replace('Bearer ', '');
      if (!token) {
        client.disconnect();
        return;
      }
      const payload = this.jwtService.verify(token, {
        secret: process.env.JWT_SECRET || 'jwt-secret-key',
      });
      client.data.user = payload;
      const rooms = await this.chatService.getRooms(payload.sub);
      for (const room of rooms) {
        client.join(room.id);
      }
    } catch {
      client.disconnect();
    }
  }

  handleDisconnect(client: Socket) {
    // Client disconnected
  }

  @SubscribeMessage('joinRoom')
  handleJoinRoom(
    @ConnectedSocket() client: Socket,
    @MessageBody() data: { roomId: string },
  ) {
    client.join(data.roomId);
    return { event: 'joinedRoom', roomId: data.roomId };
  }

  @SubscribeMessage('sendMessage')
  async handleSendMessage(
    @ConnectedSocket() client: Socket,
    @MessageBody() data: { roomId: string; content: string; attachmentUrl?: string },
  ) {
    const userId = client.data.user?.sub;
    if (!userId) return;

    const message = await this.chatService.sendMessage(data, userId);
    this.server.to(data.roomId).emit('newMessage', message);
    return message;
  }

  @SubscribeMessage('markRead')
  async handleMarkRead(
    @ConnectedSocket() client: Socket,
    @MessageBody() data: { roomId: string },
  ) {
    const userId = client.data.user?.sub;
    if (!userId) return;

    await this.chatService.markAsRead(data.roomId, userId);
    this.server.to(data.roomId).emit('readReceipt', { roomId: data.roomId, userId });
  }
}
