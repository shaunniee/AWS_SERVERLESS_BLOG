import axios from 'axios';
import { fetchAuthSession } from 'aws-amplify/auth';
import { ADMIN_API_BASE_URL } from '@/utils/constants';

const axiosInstance = axios.create({
  baseURL: ADMIN_API_BASE_URL,
  headers: {
    'Content-Type': 'application/json',
  },
});

// Request interceptor - add auth token to requests
axiosInstance.interceptors.request.use(
  async (config) => {
    try {
      const session = await fetchAuthSession();
      const idToken = session.tokens?.idToken?.toString();

      if (idToken) {
        config.headers.Authorization = `Bearer ${idToken}`;
      }
    } catch (error) {
      console.error('Error fetching auth token:', error);
    }

    return config;
  },
  (error) => {
    return Promise.reject(error);
  }
);

// Response interceptor - handle errors
axiosInstance.interceptors.response.use(
  (response) => response,
  async (error) => {
    if (error.response) {
      // Handle 401 Unauthorized - token expired
      if (error.response.status === 401) {
        console.error('Authentication expired. Please login again.');
        // Could trigger logout here
        window.location.href = '/login';
      }

      // Handle 403 Forbidden
      if (error.response.status === 403) {
        console.error('Access forbidden');
      }

      // Handle 500 Server Error
      if (error.response.status >= 500) {
        console.error('Server error:', error.response.data);
      }
    }

    return Promise.reject(error);
  }
);

export default axiosInstance;
