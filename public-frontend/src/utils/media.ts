import { MEDIA_CDN_URL } from '@/utils/constants';

const IMG_SRC_REGEX = /<img[^>]+src=["']([^"']+)["'][^>]*>/gi;

const isAbsoluteMediaSrc = (src: string): boolean =>
  src.startsWith('http://') || src.startsWith('https://') || src.startsWith('data:');

const normalizeObjectKey = (value: string): string => value.replace(/^\/+/, '').trim();

export const resolveMediaSrc = (srcOrKey: string): string => {
  const normalized = normalizeObjectKey(srcOrKey);
  if (!normalized) return '';
  if (isAbsoluteMediaSrc(normalized)) return normalized;
  if (!MEDIA_CDN_URL) return normalized;

  return `${MEDIA_CDN_URL.replace(/\/+$/, '')}/${normalized}`;
};

export const rewriteInlineImagesToCdn = (html: string): string => {
  if (!html) return '';

  return html.replace(IMG_SRC_REGEX, (imgTag, srcValue: string) => {
    const source = String(srcValue || '').trim();
    if (!source || isAbsoluteMediaSrc(source)) {
      return imgTag;
    }

    const nextSrc = resolveMediaSrc(source);
    return imgTag.replace(srcValue, nextSrc);
  });
};
