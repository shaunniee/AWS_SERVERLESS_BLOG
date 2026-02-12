import { z } from 'zod';

export const loginSchema = z.object({
  username: z.string().min(1, 'Username is required'),
  password: z.string().min(1, 'Password is required'),
});

export const postSchema = z.object({
  title: z.string().min(3, 'Title must be at least 3 characters'),
  content: z.string().min(1, 'Content is required'),
});

export type LoginFormData = z.infer<typeof loginSchema>;
export type PostFormData = z.infer<typeof postSchema>;
