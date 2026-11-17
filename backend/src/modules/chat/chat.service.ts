import { Injectable, ForbiddenException, NotFoundException } from '@nestjs/common';
import { DataSource } from 'typeorm';

@Injectable()
export class ChatService {
  constructor(private readonly dataSource: DataSource) {}

  async getRooms(userId: string) {
    return this.dataSource.query(
      `SELECT 
        cr.id,
        cr.name,
        cr.is_group,
        cr.created_at,
        cm.last_read_at,
        (
          SELECT json_build_object(
            'id', m.id,
            'content', m.content,
            'senderId', m.sender_id,
            'createdAt', m.created_at
          )
          FROM messages m 
          WHERE m.room_id = cr.id 
          ORDER BY m.created_at DESC 
          LIMIT 1
        ) AS last_message,
        (
          SELECT COUNT(*) 
          FROM messages m 
          WHERE m.room_id = cr.id 
            AND m.sender_id != $1 
            AND m.created_at > cm.last_read_at
        ) AS unread_count,
        (
          SELECT json_agg(json_build_object('id', u.id, 'fullName', u.full_name, 'avatarUrl', u.avatar_url))
          FROM chat_members cm2
          JOIN users u ON cm2.user_id = u.id
          WHERE cm2.room_id = cr.id
        ) AS members
       FROM chat_rooms cr
       JOIN chat_members cm ON cr.id = cm.room_id AND cm.user_id = $1
       ORDER BY cr.created_at DESC`,
      [userId],
    );
  }

  async getMessages(roomId: string, userId: string, query: any) {
    // Validate user is member
    const [membership] = await this.dataSource.query(
      `SELECT * FROM chat_members WHERE room_id = $1 AND user_id = $2`,
      [roomId, userId],
    );
    if (!membership) throw new ForbiddenException('Вы не состоите в этом чате');

    const limit = parseInt(query.limit || '50', 10);
    const offset = (parseInt(query.page || '1', 10) - 1) * limit;

    const messages = await this.dataSource.query(
      `SELECT m.*, u.full_name AS sender_name, u.avatar_url AS sender_avatar
       FROM messages m
       JOIN users u ON m.sender_id = u.id
       WHERE m.room_id = $1
       ORDER BY m.created_at DESC
       LIMIT $2 OFFSET $3`,
      [roomId, limit, offset],
    );

    return messages.reverse();
  }

  async createRoom(dto: { name?: string; isGroup?: boolean; memberIds: string[] }, creatorId: string) {
    const isGroup = dto.isGroup !== undefined ? dto.isGroup : dto.memberIds.length > 1;
    const allMembers = Array.from(new Set([creatorId, ...dto.memberIds]));

    // Check if direct 1-on-1 room already exists
    if (!isGroup && allMembers.length === 2) {
      const [existingRoom] = await this.dataSource.query(
        `SELECT cm1.room_id 
         FROM chat_members cm1
         JOIN chat_members cm2 ON cm1.room_id = cm2.room_id
         JOIN chat_rooms cr ON cm1.room_id = cr.id
         WHERE cm1.user_id = $1 AND cm2.user_id = $2 AND cr.is_group = false
         LIMIT 1`,
        [allMembers[0], allMembers[1]],
      );
      if (existingRoom) {
        return { id: existingRoom.room_id };
      }
    }

    const [room] = await this.dataSource.query(
      `INSERT INTO chat_rooms (name, is_group, created_by) VALUES ($1, $2, $3) RETURNING *`,
      [dto.name || null, isGroup, creatorId],
    );

    for (const memId of allMembers) {
      await this.dataSource.query(
        `INSERT INTO chat_members (room_id, user_id, role) VALUES ($1, $2, $3)`,
        [room.id, memId, memId === creatorId ? 'ADMIN' : 'MEMBER'],
      );
    }

    return room;
  }

  async sendMessage(dto: { roomId: string; content: string; attachmentUrl?: string }, senderId: string) {
    const [membership] = await this.dataSource.query(
      `SELECT * FROM chat_members WHERE room_id = $1 AND user_id = $2`,
      [dto.roomId, senderId],
    );
    if (!membership) throw new ForbiddenException('Вы не состоите в этом чате');

    const [message] = await this.dataSource.query(
      `INSERT INTO messages (room_id, sender_id, content, attachment_url)
       VALUES ($1, $2, $3, $4) RETURNING *`,
      [dto.roomId, senderId, dto.content, dto.attachmentUrl || null],
    );

    const [sender] = await this.dataSource.query(`SELECT full_name, avatar_url FROM users WHERE id = $1`, [senderId]);

    // Send push notification to other room members
    const otherMembers = await this.dataSource.query(
      `SELECT u.id, u.fcm_token 
       FROM chat_members cm
       JOIN users u ON cm.user_id = u.id
       WHERE cm.room_id = $1 AND cm.user_id != $2`,
      [dto.roomId, senderId],
    );

    for (const member of otherMembers) {
      await this.dataSource.query(
        `INSERT INTO notifications (user_id, title, body, type, reference_id)
         VALUES ($1, $2, $3, 'CHAT', $4)`,
        [
          member.id,
          sender?.full_name || 'Новое сообщение',
          dto.content.substring(0, 100),
          dto.roomId,
        ],
      );
    }

    return {
      ...message,
      sender_name: sender?.full_name,
      sender_avatar: sender?.avatar_url,
    };
  }

  async markAsRead(roomId: string, userId: string) {
    await this.dataSource.query(
      `UPDATE chat_members SET last_read_at = NOW() WHERE room_id = $1 AND user_id = $2`,
      [roomId, userId],
    );
    await this.dataSource.query(
      `UPDATE messages SET is_read = true WHERE room_id = $1 AND sender_id != $2`,
      [roomId, userId],
    );
    return { success: true };
  }
}
