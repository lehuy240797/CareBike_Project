import apiClient from './apiClient';
import type { VehicleRecord, VehicleRequest } from '../types/api';

/** GET /api/vehicles/owner/{userId} — fetch a customer's vehicle profile (404 if none) */
export const getVehicleByOwner = (userId: number): Promise<VehicleRecord[]> =>
  apiClient.get<VehicleRecord[]>(`/vehicles/owner/${userId}`).then((r) => r.data);

/** PUT /api/vehicles/owner/{userId} — create or update vehicle profile */
export const upsertVehicle = (userId: number, data: VehicleRequest): Promise<VehicleRecord> =>
  apiClient.put<VehicleRecord>(`/vehicles/owner/${userId}`, data).then((r) => r.data);
