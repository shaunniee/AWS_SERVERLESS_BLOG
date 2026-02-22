# Serverless Blog Admin Frontend

React + TypeScript admin dashboard for managing blog posts and viewing leads.

## Stack

- Vite + React 19 + TypeScript
- Tailwind CSS v4
- TanStack Query
- React Hook Form + Zod
- AWS Amplify Auth (Cognito)

## Setup

1. Install dependencies:

```bash
npm install
```

2. Create local env file:

```bash
cp .env.example .env.local
```

3. Update `.env.local` with your deployed AWS values:

- `VITE_API_BASE_URL`
- `VITE_COGNITO_USER_POOL_ID`
- `VITE_COGNITO_CLIENT_ID`
- `VITE_AWS_REGION`

## Development

```bash
npm run dev
```

App runs at `http://localhost:5173` by default.

## Build

```bash
npm run build
npm run preview
```

## Notes

- If Cognito env vars are not configured, auth is bypassed in local development so UI work can continue.
- API calls still require a valid backend URL and proper auth when your backend enforces it.
