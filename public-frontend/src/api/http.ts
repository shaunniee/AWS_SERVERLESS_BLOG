import axios from 'axios';
import { PUBLIC_API_BASE_URL } from '@/utils/constants';

export const http = axios.create({
  baseURL: PUBLIC_API_BASE_URL,
  headers: {
    'Content-Type': 'application/json',
  },
});
