import apiClient from "./apiClient";
import type { AppointmentRecord } from '../types/api';

export const appointmentService = {
  getPendingAppointments: async (branchId: number): Promise<AppointmentRecord[]> => {
    const response = await apiClient.get(`/appointments/branch/${branchId}?status=PENDING`);
    return response.data;
  },

  updateStatus: async (id: number, status: 'PENDING' | 'CONFIRMED' | 'COMPLETED' | 'CANCELLED'): Promise<AppointmentRecord> => {
    const response = await apiClient.put(`/appointments/${id}/status`, { status });
    return response.data;
  },
};

