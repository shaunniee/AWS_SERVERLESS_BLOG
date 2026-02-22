import { http } from '@/api/http';
import type { LeadRequest, LeadResponse } from '@/types/lead';

export const leadsApi = {
  submitLead: async (data: LeadRequest): Promise<LeadResponse> => {
    const response = await http.post<LeadResponse>('/leads', data);
    return response.data;
  },
};
