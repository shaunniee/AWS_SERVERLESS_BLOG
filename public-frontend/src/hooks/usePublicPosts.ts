import { useInfiniteQuery, useQuery } from '@tanstack/react-query';
import { publicPostsApi } from '@/api/public-posts';

const PUBLIC_POSTS_KEY = ['public-posts'];
const PUBLIC_POST_KEY = (postId: string) => ['public-posts', postId];

export const usePublicPosts = (limit = 9) => {
  return useInfiniteQuery({
    queryKey: [...PUBLIC_POSTS_KEY, limit],
    queryFn: ({ pageParam }) => publicPostsApi.getPublishedPosts({ limit, lastKey: pageParam }),
    initialPageParam: undefined as string | undefined,
    getNextPageParam: (lastPage) => lastPage.nextKey || undefined,
  });
};

export const usePublicPost = (postId: string) => {
  return useQuery({
    queryKey: PUBLIC_POST_KEY(postId),
    queryFn: () => publicPostsApi.getPublishedPostById(postId),
    enabled: Boolean(postId),
  });
};
