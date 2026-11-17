import { Injectable, NotFoundException } from '@nestjs/common';
import { DataSource } from 'typeorm';
import { CreateDocumentDto } from './dto/create-document.dto';
import { CreateFolderDto } from './dto/create-folder.dto';

@Injectable()
export class DocumentsService {
  constructor(private readonly dataSource: DataSource) {}

  async getFolders(parentId?: string) {
    if (parentId) {
      return this.dataSource.query(
        `SELECT df.*,
          (SELECT COUNT(*) FROM documents d WHERE d.folder_id = df.id) AS file_count
         FROM document_folders df
         WHERE df.parent_id = $1
         ORDER BY df.name ASC`,
        [parentId],
      );
    }
    return this.dataSource.query(
      `SELECT df.*,
        (SELECT COUNT(*) FROM documents d WHERE d.folder_id = df.id) AS file_count
       FROM document_folders df
       WHERE df.parent_id IS NULL
       ORDER BY df.name ASC`,
    );
  }

  async createFolder(dto: CreateFolderDto) {
    const res = await this.dataSource.query(
      `INSERT INTO document_folders (name, parent_id) VALUES ($1, $2) RETURNING *`,
      [dto.name, dto.parentId || null],
    );
    return res[0];
  }

  async getDocuments(query: { folderId?: string; search?: string }) {
    const search = query.search ? `%${query.search}%` : null;
    return this.dataSource.query(
      `SELECT d.*, u.full_name AS uploaded_by_name
       FROM documents d
       LEFT JOIN users u ON d.uploaded_by = u.id
       WHERE ($1::uuid IS NULL OR d.folder_id = $1)
         AND ($2::text IS NULL OR d.title ILIKE $2 OR d.file_name ILIKE $2)
       ORDER BY d.created_at DESC`,
      [query.folderId || null, search],
    );
  }

  async getDocumentById(id: string) {
    const [doc] = await this.dataSource.query(
      `SELECT d.*, u.full_name AS uploaded_by_name
       FROM documents d
       LEFT JOIN users u ON d.uploaded_by = u.id
       WHERE d.id = $1`,
      [id],
    );
    if (!doc) {
      throw new NotFoundException('Документ не найден');
    }
    return doc;
  }

  async createDocument(dto: CreateDocumentDto, userId?: string) {
    const res = await this.dataSource.query(
      `INSERT INTO documents (title, folder_id, file_url, file_name, file_size, mime_type, uploaded_by)
       VALUES ($1, $2, $3, $4, $5, $6, $7) RETURNING *`,
      [
        dto.title,
        dto.folderId || null,
        dto.fileUrl,
        dto.fileName,
        dto.fileSize || 0,
        dto.mimeType || 'application/octet-stream',
        userId || null,
      ],
    );
    return res[0];
  }

  async deleteDocument(id: string) {
    await this.getDocumentById(id);
    await this.dataSource.query(`DELETE FROM documents WHERE id = $1`, [id]);
    return { success: true, message: 'Документ удален' };
  }
}
