import { IsString, IsNotEmpty, IsOptional, IsEmail } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class CreateCustomerDto {
  @ApiProperty({ example: 'ООО Трейд Плюс' })
  @IsString()
  @IsNotEmpty()
  name: string;

  @ApiProperty({ example: '+998901234567', required: false })
  @IsString()
  @IsOptional()
  phone?: string;

  @ApiProperty({ example: 'info@tradeplus.uz', required: false })
  @IsEmail()
  @IsOptional()
  email?: string;

  @ApiProperty({ example: 'г. Ташкент, ул. Чиланзар 10', required: false })
  @IsString()
  @IsOptional()
  address?: string;

  @ApiProperty({ example: '123456789', required: false })
  @IsString()
  @IsOptional()
  inn?: string;

  @ApiProperty({ example: 'Надежный партнер', required: false })
  @IsString()
  @IsOptional()
  notes?: string;
}
