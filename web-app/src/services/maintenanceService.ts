import apiClient from './apiClient';
import type { MaintenanceRecord, MaintenanceRequest } from '../types/api';

/** GET /api/maintenance/customer/{userId} — fetch all maintenance records for a customer */
export const getMaintenanceByCustomer = (userId: number): Promise<MaintenanceRecord[]> =>
  apiClient.get<MaintenanceRecord[]>(`/maintenance/customer/${userId}`).then((r) => r.data);

/** POST /api/maintenance — create a new maintenance record */
export const createMaintenanceRecord = (data: MaintenanceRequest): Promise<MaintenanceRecord> =>
  apiClient.post<MaintenanceRecord>('/maintenance', data).then((r) => r.data);
