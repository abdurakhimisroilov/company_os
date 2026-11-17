import {
  Controller,
  Get,
  Post,
  Delete,
  Body,
  Param,
  Query,
  UseGuards,
  Req,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { DocumentsService } from './documents.service';
import { CreateDocumentDto } from './dto/create-document.dto';
import { CreateFolderDto } from './dto/create-folder.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';

@ApiTags('Documents')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('documents')
export class DocumentsController {
  constructor(private readonly documentsService: DocumentsService) {}

  @Get('folders')
  @ApiOperation({ summary: 'Get folders' })
  async getFolders(@Query('parentId') parentId?: string) {
    return this.documentsService.getFolders(parentId);
  }

  @Post('folders')
  @ApiOperation({ summary: 'Create folder' })
  async createFolder(@Body() dto: CreateFolderDto) {
    return this.documentsService.createFolder(dto);
  }

  @Get()
  @ApiOperation({ summary: 'Get documents' })
  async getDocuments(
    @Query('folderId') folderId?: string,
    @Query('search') search?: string,
  ) {
    return this.documentsService.getDocuments({ folderId, search });
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get document by ID' })
  async getDocumentById(@Param('id') id: string) {
    return this.documentsService.getDocumentById(id);
  }

  @Post()
  @ApiOperation({ summary: 'Upload document metadata' })
  async createDocument(@Body() dto: CreateDocumentDto, @Req() req: any) {
    return this.documentsService.createDocument(dto, req.user?.id);
  }

  @Delete(':id')
  @ApiOperation({ summary: 'Delete document' })
  async deleteDocument(@Param('id') id: string) {
    return this.documentsService.deleteDocument(id);
  }
}
