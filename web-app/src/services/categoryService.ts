import apiClient from './apiClient';

export interface CategoryRecord {
  id: number;
  name: string;
  description?: string;
}

export const getCategories = async (): Promise<CategoryRecord[]> => {
  const { data } = await apiClient.get('/categories');
  return data;
};

export const createCategory = async (payload: { name: string; description?: string }): Promise<CategoryRecord> => {
  const { data } = await apiClient.post('/categories', payload);
  return data;
};

export const deleteCategory = async (id: number): Promise<void> => {
  await apiClient.delete(`/categories/${id}`);
};
