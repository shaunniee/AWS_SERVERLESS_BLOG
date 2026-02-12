import { MEDIA_CDN_URL } from '@/utils/constants';

const IMG_SRC_REGEX = /<img[^>]+src=["']([^"']+)["'][^>]*>/gi;

const isAbsoluteMediaSrc = (src: string): boolean =>
  src.startsWith('http://') || src.startsWith('https://') || src.startsWith('data:');

const normalizeObjectKey = (value: string): string => value.replace(/^\/+/, '').trim();

export const extractImageKeysFromHtml = (html: string): string[] => {
  if (!html) return [];

  const matches = Array.from(html.matchAll(IMG_SRC_REGEX));
  const keys = matches
    .map((match) => normalizeObjectKey(match[1] || ''))
    .filter((src) => src.length > 0 && !isAbsoluteMediaSrc(src));

  return Array.from(new Set(keys));
};

export const resolveMediaSrc = (srcOrKey: string): string => {
  const normalized = normalizeObjectKey(srcOrKey);
  if (!normalized) return '';
  if (isAbsoluteMediaSrc(normalized)) return normalized;
  if (!MEDIA_CDN_URL) return normalized;

  return `${MEDIA_CDN_URL.replace(/\/+$/, '')}/${normalized}`;
};

