import axios from './axios-instance';
import type { Lead } from '@/types/lead';

export const leadsApi = {
  // Get all leads
  getAll: async (): Promise<Lead[]> => {
    const response = await axios.get<Lead[]>('/admin/leads');
    return response.data;
  },
};
