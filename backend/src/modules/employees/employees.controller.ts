import {
  Controller,
  Get,
  Post,
  Put,
  Delete,
  Body,
  Param,
  Query,
  UseGuards,
  Req,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { EmployeesService } from './employees.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';

@ApiTags('Employees')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('employees')
export class EmployeesController {
  constructor(private readonly employeesService: EmployeesService) {}

  @Get()
  @ApiOperation({ summary: 'Get employees list' })
  async getEmployees(@Query() query: any) {
    return this.employeesService.getEmployees(query);
  }

  @Get('departments')
  @ApiOperation({ summary: 'Get all departments' })
  async getDepartments() {
    return this.employeesService.getDepartments();
  }

  @Post('departments')
  @Roles('SUPER_ADMIN', 'ADMIN')
  @ApiOperation({ summary: 'Create new department' })
  async createDepartment(@Body() dto: any) {
    return this.employeesService.createDepartment(dto);
  }

  @Post('departments/:id/manager')
  @Roles('SUPER_ADMIN', 'ADMIN')
  @ApiOperation({ summary: 'Assign department manager' })
  async assignManager(@Param('id') deptId: string, @Body('employeeId') employeeId: string) {
    return this.employeesService.assignManager(deptId, employeeId);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get employee details' })
  async getEmployeeById(@Param('id') id: string) {
    return this.employeesService.getEmployeeById(id);
  }

  @Post()
  @Roles('SUPER_ADMIN', 'ADMIN')
  @ApiOperation({ summary: 'Create new employee' })
  async createEmployee(@Body() dto: any) {
    return this.employeesService.createEmployee(dto);
  }

  @Put(':id')
  @Roles('SUPER_ADMIN', 'ADMIN')
  @ApiOperation({ summary: 'Update employee info' })
  async updateEmployee(@Param('id') id: string, @Body() dto: any) {
    return this.employeesService.updateEmployee(id, dto);
  }

  @Put(':id/role')
  @Roles('SUPER_ADMIN')
  @ApiOperation({ summary: 'Update employee role (SUPER_ADMIN only)' })
  async updateRole(@Param('id') id: string, @Body('role') role: string, @Req() req: any) {
    return this.employeesService.updateRole(id, role, req.user?.role);
  }

  @Delete(':id')
  @Roles('SUPER_ADMIN', 'ADMIN')
  @ApiOperation({ summary: 'Deactivate employee' })
  async deactivateEmployee(@Param('id') id: string) {
    return this.employeesService.deactivateEmployee(id);
  }

  @Get(':id/stats')
  @ApiOperation({ summary: 'Get employee workload stats' })
  async getEmployeeStats(@Param('id') id: string) {
    return this.employeesService.getEmployeeStats(id);
  }
}
