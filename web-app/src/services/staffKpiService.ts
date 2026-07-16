import apiClient from './apiClient';

export interface StaffKpiRecord {
  staffId: number;
  staffCode: string;
  fullName: string;
  status: string;
  completedAppointments: number;
  completedRescues: number;
  totalCompleted: number;
}

export interface StaffKpiFilters {
  from?: string;
  to?: string;
}

export const apiGetStaffKpis = async (
  branchId: number,
  filters: StaffKpiFilters = {},
): Promise<StaffKpiRecord[]> => {
  const response = await apiClient.get(`/staff/branch/${branchId}/kpi`, { params: filters });
  return response.data;
};
