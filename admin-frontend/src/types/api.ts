export interface ApiError {
  message: string;
  statusCode?: number;
}

export interface PresignedUrlResponse {
  uploadUrl: string;
  objectKey: string;
  key?: string;
  expiresIn: number;
}
