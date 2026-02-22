import { useMutation } from '@tanstack/react-query';
import { leadsApi } from '@/api/leads';
import type { LeadRequest } from '@/types/lead';

export const useContactForm = () => {
  return useMutation({
    mutationFn: (data: LeadRequest) => leadsApi.submitLead(data),
  });
};
