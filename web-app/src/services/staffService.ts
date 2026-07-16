import apiClient from './apiClient';

export interface StaffRecord {
  id: number;
  staffCode: string;
  fullName: string;
  phone: string;
  status?: string;
}

export interface ShiftRecord {
  id?: number;
  staff: StaffRecord;
  shiftDate: string; // Updated from dayOfWeek to shiftDate (YYYY-MM-DD)
  shiftType: string;
}

export const apiGetStaffByBranch = async (branchId: number): Promise<StaffRecord[]> => {
  const response = await apiClient.get(`/staff/branch/${branchId}`);
  return response.data;
};

export const apiGetShiftsByBranch = async (branchId: number, startDate: string, endDate: string): Promise<ShiftRecord[]> => {
  const response = await apiClient.get(`/staff/shifts/branch/${branchId}?startDate=${startDate}&endDate=${endDate}`);
  return response.data;
};

export const apiUpdateShifts = async (branchId: number, startDate: string, endDate: string, shiftsData: any[]): Promise<any> => {
  const response = await apiClient.put(`/staff/shifts/branch/${branchId}?startDate=${startDate}&endDate=${endDate}`, shiftsData);
  return response.data;
};

export const apiCreateStaff = async (branchId: number, data: Partial<StaffRecord>): Promise<StaffRecord> => {
  const response = await apiClient.post(`/staff/branch/${branchId}`, data);
  return response.data;
};

export const apiUpdateStaff = async (staffId: number, data: Partial<StaffRecord>): Promise<StaffRecord> => {
  const response = await apiClient.put(`/staff/${staffId}`, data);
  return response.data;
};

export const apiDeleteStaff = async (staffId: number): Promise<void> => {
  await apiClient.delete(`/staff/${staffId}`);
};

export const apiUpdateStaffStatus = async (staffId: number, status: string): Promise<void> => {
  await apiClient.put(`/staff/${staffId}/status`, { status });
};
