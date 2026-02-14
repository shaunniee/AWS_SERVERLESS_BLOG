import { useQuery } from '@tanstack/react-query';
import { leadsApi } from '@/api/leads';

// Query keys
const LEADS_KEY = ['leads'];

// Get all leads
export const useLeads = () => {
  return useQuery({
    queryKey: LEADS_KEY,
    queryFn: leadsApi.getAll,
  });
};
