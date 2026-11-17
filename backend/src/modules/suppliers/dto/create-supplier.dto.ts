import { IsString, IsNotEmpty, IsOptional, IsEmail } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class CreateSupplierDto {
  @ApiProperty({ example: 'ООO Импорт Снабжение' })
  @IsString()
  @IsNotEmpty()
  name: string;

  @ApiProperty({ example: 'Иван Петров', required: false })
  @IsString()
  @IsOptional()
  contactPerson?: string;

  @ApiProperty({ example: '+998909876543', required: false })
  @IsString()
  @IsOptional()
  phone?: string;

  @ApiProperty({ example: 'supplier@import.uz', required: false })
  @IsEmail()
  @IsOptional()
  email?: string;

  @ApiProperty({ example: 'г. Ташкент, Сергели 4', required: false })
  @IsString()
  @IsOptional()
  address?: string;

  @ApiProperty({ example: '987654321', required: false })
  @IsString()
  @IsOptional()
  inn?: string;
}
