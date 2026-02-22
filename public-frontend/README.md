# Public Frontend

Standalone public-facing frontend for reading published posts.

## Setup

1. Copy env file:

```bash
cp .env.example .env.local
```

2. Install and run:

```bash
npm install
npm run dev
```

## Required env vars

- `VITE_PUBLIC_API_BASE_URL`: Public API Gateway URL
- `VITE_MEDIA_CDN_URL`: CloudFront domain for media assets
