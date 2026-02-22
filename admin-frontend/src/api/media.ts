import axios from './axios-instance';
import type { PresignedUrlResponse } from '@/types/api';

export const mediaApi = {
  // Get presigned URL for uploading media to S3
  getPresignedUrl: async (
    fileName: string,
    contentType: string
  ): Promise<PresignedUrlResponse> => {
    const response = await axios.post<PresignedUrlResponse>(
      '/admin/media/upload_url',
      {
        fileName,
        contentType,
      }
    );
    return response.data;
  },
};
