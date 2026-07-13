// ─── Vehicle ──────────────────────────────────────────────────────────────────

export interface VehicleRecord {
  id: number;
  brand: string;
  vehicleType: string;  // 'XE_SO' | 'XE_TAY_GA'
  vehicleName: string;
  licensePlate: string | null;
  engineCapacity: number | null;
  currentKm: number | null;
  owner: { id: number; username: string; fullName: string };
}

export interface VehicleRequest {
  brand: string;
  vehicleType: string;
  vehicleName: string;
  chassisNumber: string;
  engineNumber: string;
}

// ─── Maintenance History ───────────────────────────────────────────────────────

export interface MaintenanceRecord {
  id: number;
  serviceDate: string;   // ISO date: '2024-03-15'
  currentKm: number | null;
  serviceDetails: string | null;
  totalCost: number | null;
  customer: { id: number; username: string; fullName: string };
  branch: { id: number; name: string } | null;
}

export interface MaintenanceRequest {
  serviceDate: string;
  currentKm: number;
  serviceDetails: string;
  totalCost: number;
  customerId: number;
  branchId: number | null;
}

// ─── Branch ───────────────────────────────────────────────────────────────────

export interface BranchRequest {
  // Branch physical fields
  name: string;
  address: string;
  phone: string;
  status: string;
  latitude?: number | null;
  longitude?: number | null;
  // Edit mode: link existing manager by ID
  managerId?: number | null;
  // Create mode: provision a new manager account in one transaction
  managerUsername?: string;
  managerPassword?: string;
  managerEmail?: string;
  managerFullName?: string;
}

// ─── Customer Loyalty Profile ─────────────────────────────────────────────────

export type MemberTier = 'STANDARD' | 'SILVER' | 'GOLD' | 'PLATINUM';

export interface CustomerProfile {
  id: number;
  user: { id: number; username: string; fullName: string };
  accumulatedPoints: number;
  memberTier: MemberTier;
  totalSpent: number;
}

// ─── Appointment ───────────────────────────────────────────────────────────────

export interface AppointmentRecord {
  id: number;
  customerId: number;
  branchId: number;
  appointmentDate: string;
  note?: string;
  status: 'PENDING' | 'CONFIRMED' | 'COMPLETED' | 'CANCELLED';
  customerName?: string;
  customerPhone?: string;
  branchName?: string;
}