import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { postsApi } from '@/api/posts';
import type { CreatePostInput, UpdatePostInput } from '@/types/post';

// Query keys
const POSTS_KEY = ['posts'];
const POST_KEY = (id: string) => ['posts', id];

// Get all posts
export const usePosts = () => {
  return useQuery({
    queryKey: POSTS_KEY,
    queryFn: postsApi.getAll,
  });
};

// Get single post
export const usePost = (postId: string) => {
  return useQuery({
    queryKey: POST_KEY(postId),
    queryFn: () => postsApi.getById(postId),
    enabled: !!postId,
  });
};

// Create post
export const useCreatePost = () => {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (data: CreatePostInput) => postsApi.create(data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: POSTS_KEY });
    },
  });
};

// Update post
export const useUpdatePost = () => {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: ({ postId, data }: { postId: string; data: UpdatePostInput }) =>
      postsApi.update(postId, data),
    onSuccess: (_, variables) => {
      queryClient.invalidateQueries({ queryKey: POSTS_KEY });
      queryClient.invalidateQueries({ queryKey: POST_KEY(variables.postId) });
    },
  });
};

// Delete post
export const useDeletePost = () => {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (postId: string) => postsApi.delete(postId),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: POSTS_KEY });
    },
  });
};

// Publish post
export const usePublishPost = () => {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (postId: string) => postsApi.publish(postId),
    onSuccess: (_, postId) => {
      queryClient.invalidateQueries({ queryKey: POSTS_KEY });
      queryClient.invalidateQueries({ queryKey: POST_KEY(postId) });
    },
  });
};

// Unpublish post
export const useUnpublishPost = () => {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (postId: string) => postsApi.unpublish(postId),
    onSuccess: (_, postId) => {
      queryClient.invalidateQueries({ queryKey: POSTS_KEY });
      queryClient.invalidateQueries({ queryKey: POST_KEY(postId) });
    },
  });
};

// Archive post
export const useArchivePost = () => {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (postId: string) => postsApi.archive(postId),
    onSuccess: (_, postId) => {
      queryClient.invalidateQueries({ queryKey: POSTS_KEY });
      queryClient.invalidateQueries({ queryKey: POST_KEY(postId) });
    },
  });
};
