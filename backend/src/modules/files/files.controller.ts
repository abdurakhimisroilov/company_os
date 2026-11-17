import {
  Controller,
  Post,
  Get,
  Delete,
  Param,
  UseInterceptors,
  UploadedFile,
  UseGuards,
  Req,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { ApiTags, ApiOperation, ApiBearerAuth, ApiConsumes } from '@nestjs/swagger';
import { FilesService } from './files.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';

@ApiTags('Files')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('files')
export class FilesController {
  constructor(private readonly filesService: FilesService) {}

  @Post('upload')
  @ApiOperation({ summary: 'Upload file to MinIO object storage' })
  @ApiConsumes('multipart/form-data')
  @UseInterceptors(FileInterceptor('file'))
  async uploadFile(@UploadedFile() file: Express.Multer.File, @Req() req: any) {
    return this.filesService.uploadFile(file, req.user?.id);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get signed URL for file access' })
  async getFileUrl(@Param('id') id: string) {
    return this.filesService.getSignedUrl(id);
  }

  @Delete(':id')
  @ApiOperation({ summary: 'Delete file' })
  async deleteFile(@Param('id') id: string) {
    return this.filesService.deleteFile(id);
  }
}
