import apiClient from './apiClient';
import type { BranchRequest } from '../types/api';

// ─── Type ─────────────────────────────────────────────────────────────────────

export interface BranchRecord {
  id: number;
  name: string;
  address: string;
  phone: string;
  latitude?: number;
  longitude?: number;
  status: string;
  manager?: {
    id: number;
    username: string;
    fullName: string;
    email: string;
    phone: string;
  };
}

// ─── API functions ─────────────────────────────────────────────────────────────

/** GET /api/branches */
export const getBranches = (): Promise<BranchRecord[]> =>
  apiClient.get<BranchRecord[]>('/branches').then((r) => r.data);

/** POST /api/branches */
export const createBranch = (data: BranchRequest): Promise<BranchRecord> =>
  apiClient.post<BranchRecord>('/branches', data).then((r) => r.data);

/** PUT /api/branches/:id */
export const updateBranch = (id: number, data: BranchRequest): Promise<BranchRecord> =>
  apiClient.put<BranchRecord>(`/branches/${id}`, data).then((r) => r.data);

/** DELETE /api/branches/:id */
export const deleteBranch = (id: number): Promise<void> =>
  apiClient.delete(`/branches/${id}`).then(() => undefined);