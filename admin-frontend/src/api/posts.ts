import axios from './axios-instance';
import type { Post, CreatePostInput, UpdatePostInput } from '@/types/post';

export const postsApi = {
  // Get all posts by current user
  getAll: async (): Promise<Post[]> => {
    const response = await axios.get<Post[]>('/admin/posts');
    return response.data;
  },

  // Get single post by ID
  getById: async (postId: string): Promise<Post> => {
    const response = await axios.get<Post>(`/admin/posts/${postId}`);
    return response.data;
  },

  // Create new post (defaults to DRAFT status)
  create: async (data: CreatePostInput): Promise<Post> => {
    const response = await axios.post<Post>('/admin/posts', data);
    return response.data;
  },

  // Update post content (only DRAFT/UNPUBLISHED can be updated)
  update: async (postId: string, data: UpdatePostInput): Promise<Post> => {
    const response = await axios.put<Post>(`/admin/posts/${postId}`, data);
    return response.data;
  },

  // Delete post permanently
  delete: async (postId: string): Promise<void> => {
    await axios.delete(`/admin/posts/${postId}`);
  },

  // Publish post (DRAFT/UNPUBLISHED → PUBLISHED)
  publish: async (postId: string): Promise<Post> => {
    const response = await axios.post<Post>(`/admin/posts/${postId}/publish`);
    return response.data;
  },

  // Unpublish post (PUBLISHED → UNPUBLISHED)
  unpublish: async (postId: string): Promise<Post> => {
    const response = await axios.post<Post>(`/admin/posts/${postId}/unpublish`);
    return response.data;
  },

  // Archive post (Any status → ARCHIVED)
  archive: async (postId: string): Promise<Post> => {
    const response = await axios.post<Post>(`/admin/posts/${postId}/archive`);
    return response.data;
  },
};
