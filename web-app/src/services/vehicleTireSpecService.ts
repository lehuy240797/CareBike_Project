import apiClient from './apiClient';

export interface VehicleTireSpec {
  id: number;
  brand: string;
  vehicleName: string;
  vehicleType: string;
  engineCapacity: number | null;
  frontTireSize: string;
  rearTireSize: string;
  note: string | null;
}

export interface VehicleTireSpecPayload {
  brand: string;
  vehicleName: string;
  vehicleType: string;
  engineCapacity: number | null;
  frontTireSize: string;
  rearTireSize: string;
  note?: string | null;
}

export const getVehicleTireSpecs = async (): Promise<VehicleTireSpec[]> => {
  const { data } = await apiClient.get('/vehicle-tire-specs');
  return data;
};

export const createVehicleTireSpec = async (
  payload: VehicleTireSpecPayload,
): Promise<VehicleTireSpec> => {
  const { data } = await apiClient.post('/vehicle-tire-specs', payload);
  return data;
};

export const updateVehicleTireSpec = async (
  id: number,
  payload: VehicleTireSpecPayload,
): Promise<VehicleTireSpec> => {
  const { data } = await apiClient.put(`/vehicle-tire-specs/${id}`, payload);
  return data;
};

export const deleteVehicleTireSpec = async (id: number): Promise<void> => {
  await apiClient.delete(`/vehicle-tire-specs/${id}`);
};
