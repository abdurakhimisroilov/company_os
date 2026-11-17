import { Injectable, Logger } from '@nestjs/common';
import { DataSource } from 'typeorm';
import * as admin from 'firebase-admin';

@Injectable()
export class NotificationsService {
  private readonly logger = new Logger(NotificationsService.name);
  private firebaseInitialized = false;

  constructor(private readonly dataSource: DataSource) {
    this.initFirebase();
  }

  private initFirebase() {
    try {
      if (admin.apps.length === 0 && process.env.FIREBASE_PROJECT_ID) {
        admin.initializeApp({
          credential: admin.credential.cert({
            projectId: process.env.FIREBASE_PROJECT_ID,
            clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
            privateKey: process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, '\n'),
          }),
        });
        this.firebaseInitialized = true;
      }
    } catch (err) {
      this.logger.warn('Firebase Admin SDK not initialized with credentials, push notifications will be simulated');
    }
  }

  async sendPushNotification(userId: string, title: string, body: string, data?: Record<string, string>) {
    try {
      const [user] = await this.dataSource.query(`SELECT fcm_token FROM users WHERE id = $1`, [userId]);
      if (!user?.fcm_token) {
        return { success: false, message: 'User has no registered FCM token' };
      }

      if (this.firebaseInitialized) {
        await admin.messaging().send({
          token: user.fcm_token,
          notification: { title, body },
          data: data || {},
        });
        return { success: true, message: 'Push sent' };
      } else {
        this.logger.log(`[Simulated Push] To: ${userId}, Title: "${title}", Body: "${body}"`);
        return { success: true, simulated: true };
      }
    } catch (err) {
      this.logger.error(`Failed to send push notification to ${userId}:`, err);
      return { success: false, error: err.message };
    }
  }

  async createNotification(userId: string, title: string, body: string, type?: string, referenceId?: string) {
    const res = await this.dataSource.query(
      `INSERT INTO notifications (user_id, title, body, type, reference_id)
       VALUES ($1, $2, $3, $4, $5) RETURNING *`,
      [userId, title, body, type || 'SYSTEM', referenceId || null],
    );

    // Also trigger push
    await this.sendPushNotification(userId, title, body, {
      type: type || 'SYSTEM',
      referenceId: referenceId || '',
    });

    return res[0];
  }

  async getUnreadNotifications(userId: string) {
    return this.dataSource.query(
      `SELECT * FROM notifications 
       WHERE user_id = $1 AND is_read = false 
       ORDER BY created_at DESC 
       LIMIT 50`,
      [userId],
    );
  }

  async getAllNotifications(userId: string, query: any) {
    const limit = parseInt(query.limit || '30', 10);
    const offset = (parseInt(query.page || '1', 10) - 1) * limit;

    return this.dataSource.query(
      `SELECT * FROM notifications WHERE user_id = $1 ORDER BY created_at DESC LIMIT $2 OFFSET $3`,
      [userId, limit, offset],
    );
  }

  async markAllRead(userId: string) {
    await this.dataSource.query(
      `UPDATE notifications SET is_read = true WHERE user_id = $1`,
      [userId],
    );
    return { success: true, message: 'Все уведомления прочитаны' };
  }

  async markRead(id: string, userId: string) {
    await this.dataSource.query(
      `UPDATE notifications SET is_read = true WHERE id = $1 AND user_id = $2`,
      [id, userId],
    );
    return { success: true };
  }
}
