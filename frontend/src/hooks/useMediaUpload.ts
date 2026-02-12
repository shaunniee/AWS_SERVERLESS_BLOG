import { useState } from 'react';
import axios from 'axios';
import { mediaApi } from '@/api/media';

export const useMediaUpload = () => {
  const [uploading, setUploading] = useState(false);
  const [progress, setProgress] = useState(0);

  const upload = async (file: File): Promise<string> => {
    setUploading(true);
    setProgress(0);

    try {
      // Step 1: Get presigned URL from backend
      const { uploadUrl, objectKey, key } = await mediaApi.getPresignedUrl(
        file.name,
        file.type
      );
      const resolvedObjectKey = objectKey || key;

      if (!uploadUrl || !resolvedObjectKey) {
        throw new Error('Invalid presigned URL response from server');
      }

      // Step 2: Upload file directly to S3 using presigned URL
      await axios.put(uploadUrl, file, {
        headers: {
          'Content-Type': file.type,
        },
        onUploadProgress: (progressEvent) => {
          if (progressEvent.total) {
            const percentCompleted = Math.round(
              (progressEvent.loaded * 100) / progressEvent.total
            );
            setProgress(percentCompleted);
          }
        },
      });

      // Step 3: Return the object key (or construct public URL if CloudFront is configured)
      // For now, just return the object key
      // TODO: If you have a CloudFront distribution for media, construct the URL here
      // const publicUrl = `https://your-cloudfront-domain.cloudfront.net/${objectKey}`;

      setUploading(false);
      setProgress(100);

      return resolvedObjectKey;
    } catch (error) {
      setUploading(false);
      setProgress(0);
      throw error;
    }
  };

  return {
    upload,
    uploading,
    progress,
  };
};
