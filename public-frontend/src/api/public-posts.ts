import { http } from '@/api/http';
import type { Post, PublicPostsResponse } from '@/types/post';

export const publicPostsApi = {
  getPublishedPosts: async (params?: { limit?: number; lastKey?: string }): Promise<PublicPostsResponse> => {
    const response = await http.get<PublicPostsResponse>('/posts', { params });
    return response.data;
  },

  getPublishedPostById: async (postId: string): Promise<Post> => {
    const response = await http.get<Post>(`/posts/${postId}`);
    return response.data;
  },
};
