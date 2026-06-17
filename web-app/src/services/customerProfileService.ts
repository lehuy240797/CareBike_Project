import apiClient from './apiClient';
import type { CustomerProfile } from '../types/api';

/** GET /api/customer-profiles — all loyalty profiles */
export const getAllProfiles = (): Promise<CustomerProfile[]> =>
  apiClient.get<CustomerProfile[]>('/customer-profiles').then((r) => r.data);

/** GET /api/customer-profiles/user/{userId} — profile for one customer (404 if none) */
export const getProfileByUser = (userId: number): Promise<CustomerProfile> =>
  apiClient.get<CustomerProfile>(`/customer-profiles/user/${userId}`).then((r) => r.data);
