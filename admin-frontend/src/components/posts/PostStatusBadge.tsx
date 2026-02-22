import { Badge } from '@/components/ui/badge';
import { POST_STATUS_LABELS, POST_STATUS_COLORS } from '@/utils/constants';
import type { PostStatus } from '@/types/post';
import type { BadgeProps } from '@/components/ui/badge';

interface PostStatusBadgeProps {
  status: PostStatus;
}

export const PostStatusBadge = ({ status }: PostStatusBadgeProps) => {
  const variant = POST_STATUS_COLORS[status] || 'secondary';
  const label = POST_STATUS_LABELS[status] || status;

  return <Badge variant={variant as BadgeProps['variant']}>{label}</Badge>;
};
