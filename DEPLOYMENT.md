# TREK — Railway Deployment Guide

## Overview

TREK deploys as a **single Docker container** on Railway with two persistent volumes.
The architecture requires a long-running process (WebSocket, cron scheduler, SQLite),
making serverless platforms like Vercel incompatible.

## Prerequisites

- [Railway CLI](https://docs.railway.com/guides/cli) installed: `npm i -g @railway/cli`
- Railway account with a team/project
- `openssl` for generating encryption keys

## Quick Deploy

```bash
# Login to Railway
railway login

# Run the deploy script
./scripts/deploy-railway.sh
```

## Manual Setup

### 1. Create project and link

```bash
railway init --name trek
railway link
```

### 2. Configure persistent volumes

In the Railway dashboard (Settings → Volumes):

| Mount Path     | Purpose                                          |
|----------------|--------------------------------------------------|
| `/app/data`    | SQLite DB, JWT secret, encryption key, logs, backups |
| `/app/uploads` | User files: photos, covers, avatars, documents   |

> **Critical:** Without these volumes, all data is lost on redeploy.

### 3. Set environment variables

```bash
railway variables set \
  NODE_ENV=production \
  PORT=3000 \
  ENCRYPTION_KEY="$(openssl rand -hex 32)" \
  TZ=UTC \
  LOG_LEVEL=info \
  ALLOWED_ORIGINS=https://your-domain.com \
  FORCE_HTTPS=true \
  TRUST_PROXY=1 \
  COOKIE_SECURE=true
```

### 4. Deploy

```bash
railway up --detach
```

### 5. Add a custom domain

```bash
railway domain
```

Then set `ALLOWED_ORIGINS` and `APP_URL` to match your domain.

## Environment Variables Reference

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `PORT` | Yes | `3000` | Server port (Railway injects this) |
| `NODE_ENV` | Yes | — | Must be `production` |
| `ENCRYPTION_KEY` | Yes | auto-gen | 256-bit hex key for encrypting secrets |
| `TZ` | No | `UTC` | Timezone for logs and scheduled tasks |
| `LOG_LEVEL` | No | `info` | `info` or `debug` |
| `ALLOWED_ORIGINS` | Yes | — | Comma-separated CORS origins |
| `FORCE_HTTPS` | Yes | `false` | Enable HTTPS redirect + HSTS |
| `TRUST_PROXY` | Yes | — | Set to `1` behind Railway's proxy |
| `COOKIE_SECURE` | No | auto | Force secure cookies |
| `APP_URL` | If OIDC/MCP | — | Public base URL of the instance |
| `ADMIN_EMAIL` | No | — | Initial admin email (first boot only) |
| `ADMIN_PASSWORD` | No | — | Initial admin password (first boot only) |
| `OIDC_ISSUER` | If SSO | — | OpenID Connect provider URL |
| `OIDC_CLIENT_ID` | If SSO | — | OIDC client ID |
| `OIDC_CLIENT_SECRET` | If SSO | — | OIDC client secret |
| `DEMO_MODE` | No | `false` | Resets data hourly for demos |

## Architecture

```
┌─────────────────────────────────────────────────┐
│              Railway Container                   │
│                                                 │
│  ┌───────────────────────────────────────────┐  │
│  │           Express Server (:3000)          │  │
│  │                                           │  │
│  │  ┌─────────┐ ┌──────┐ ┌──────────────┐  │  │
│  │  │ REST API│ │  SPA │ │ Static Files │  │  │
│  │  │ /api/*  │ │  /*  │ │  /uploads/*  │  │  │
│  │  └─────────┘ └──────┘ └──────────────┘  │  │
│  │                                           │  │
│  │  ┌──────────┐ ┌─────┐ ┌────────────┐   │  │
│  │  │WebSocket │ │ MCP │ │  Scheduler │   │  │
│  │  │   /ws    │ │/mcp │ │  (cron)    │   │  │
│  │  └──────────┘ └─────┘ └────────────┘   │  │
│  └───────────────────────────────────────────┘  │
│                                                 │
│  ┌─────────────────┐  ┌─────────────────────┐  │
│  │  /app/data (vol) │  │ /app/uploads (vol)  │  │
│  │  • travel.db     │  │ • photos/           │  │
│  │  • .jwt_secret   │  │ • files/            │  │
│  │  • .encryption_key│  │ • covers/           │  │
│  │  • logs/         │  │ • avatars/           │  │
│  │  • backups/      │  │                     │  │
│  └─────────────────┘  └─────────────────────┘  │
└─────────────────────────────────────────────────┘
```

## Health Check

Railway is configured to probe `GET /api/health` which returns:

```json
{ "status": "ok" }
```

## Updating

Push to your linked branch or run:

```bash
railway up --detach
```

Railway will rebuild the Docker image and perform a zero-downtime redeploy.
Volumes persist across deployments.

## Backups

TREK includes built-in automatic backups (configured via Admin panel).
Backups are stored at `/app/data/backups/` inside the persistent volume.

For additional safety, consider Railway's volume snapshots or periodic
export of the backup zip files.

## Troubleshooting

| Issue | Fix |
|-------|-----|
| WebSocket disconnects | Ensure no aggressive proxy timeout; Railway supports WS natively |
| Data lost on redeploy | Volumes not attached — check Settings → Volumes |
| CORS errors | Set `ALLOWED_ORIGINS` to your exact domain (with https://) |
| Login redirect loops | Set `APP_URL` and verify `FORCE_HTTPS=true` with `TRUST_PROXY=1` |
| MCP auth failures | Ensure `APP_URL` matches the OAuth redirect URI |
