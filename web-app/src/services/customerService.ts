import apiClient from './apiClient';
import type { UserRecord } from './userService';

/** GET /api/users → all users (filter CUSTOMER role client-side) */
export const getCustomers = (): Promise<UserRecord[]> =>
  apiClient.get<UserRecord[]>('/users').then((r) => r.data);