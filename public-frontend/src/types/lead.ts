export interface LeadRequest {
  name: string;
  email: string;
  message: string;
}

export interface LeadResponse {
  leadID: string;
  name: string;
  email: string;
  message: string;
  status: string;
  createdAt: string;
}
