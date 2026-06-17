import apiClient from './apiClient';

// ─── Types ─────────────────────────────────────────────────────────────────────

export interface UserRecord {
  id: number;
  username: string;
  email: string;
  fullName: string;
  phone: string;
  isActive: boolean;
  role: { id: number; roleName: string };
  createdAt: string;
}

// ─── API functions ─────────────────────────────────────────────────────────────

/** GET /api/users */
export const apiGetAllUsers = (): Promise<UserRecord[]> =>
  apiClient.get<UserRecord[]>('/users').then((r) => r.data);

/** GET /api/users/:id */
export const apiGetUserById = (id: number): Promise<UserRecord> =>
  apiClient.get<UserRecord>(`/users/${id}`).then((r) => r.data);

/** PUT /api/users/:id/toggle-status */
export const apiToggleUserStatus = (id: number): Promise<UserRecord> =>
  apiClient.put<UserRecord>(`/users/${id}/toggle-status`).then((r) => r.data);

// GET /api/users/available-managers?currentBranchId=xxx
export const apiGetAvailableManagers = (currentBranchId?: number): Promise<UserRecord[]> => {
  const params = currentBranchId != null ? { currentBranchId } : {};
  return apiClient
    .get<UserRecord[]>('/users/available-managers', { params })
    .then((r) => r.data);
};

// DELETE /api/users/:id
export const apiDeleteUser = (id: number): Promise<void> =>
  apiClient.delete(`/users/${id}`).then(() => undefined);