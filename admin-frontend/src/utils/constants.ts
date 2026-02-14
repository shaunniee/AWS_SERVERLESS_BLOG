export const ADMIN_API_BASE_URL =
  import.meta.env.VITE_ADMIN_API_BASE_URL || import.meta.env.VITE_API_BASE_URL || '';
export const PUBLIC_API_BASE_URL =
  import.meta.env.VITE_PUBLIC_API_BASE_URL || '';
export const MEDIA_CDN_URL =
  import.meta.env.VITE_MEDIA_CDN_URL || '';
export const COGNITO_USER_POOL_ID = import.meta.env.VITE_COGNITO_USER_POOL_ID || '';
export const COGNITO_CLIENT_ID = import.meta.env.VITE_COGNITO_CLIENT_ID || '';
export const AUTH_CONFIGURED =
  Boolean(COGNITO_USER_POOL_ID) &&
  Boolean(COGNITO_CLIENT_ID) &&
  !COGNITO_USER_POOL_ID.includes('xxxxxxxx') &&
  !COGNITO_CLIENT_ID.includes('xxxxxxxx');

export const POST_STATUS = {
  DRAFT: 'DRAFT',
  PUBLISHED: 'PUBLISHED',
  UNPUBLISHED: 'UNPUBLISHED',
  ARCHIVED: 'ARCHIVED',
} as const;

export const POST_STATUS_LABELS: Record<string, string> = {
  DRAFT: 'Draft',
  PUBLISHED: 'Published',
  UNPUBLISHED: 'Unpublished',
  ARCHIVED: 'Archived',
};

export const POST_STATUS_COLORS: Record<string, 'secondary' | 'default' | 'outline' | 'destructive'> = {
  DRAFT: 'secondary',
  PUBLISHED: 'default',
  UNPUBLISHED: 'outline',
  ARCHIVED: 'destructive',
};
