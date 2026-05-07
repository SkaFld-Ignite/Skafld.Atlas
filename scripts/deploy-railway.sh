#!/usr/bin/env bash
set -euo pipefail

# ─────────────────────────────────────────────────────────────
# TREK — Railway Deployment Script
# Deploys the TREK travel planner to Railway with persistent
# volumes for SQLite and file uploads.
# ─────────────────────────────────────────────────────────────

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()  { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# ─── Preflight checks ───────────────────────────────────────

command -v railway >/dev/null 2>&1 || error "Railway CLI not installed. Install with: npm i -g @railway/cli"
command -v openssl >/dev/null 2>&1 || error "openssl not found — needed to generate ENCRYPTION_KEY"

info "Checking Railway authentication..."
railway whoami >/dev/null 2>&1 || error "Not logged in. Run: railway login"
success "Authenticated with Railway"

# ─── Generate encryption key ────────────────────────────────

ENCRYPTION_KEY="${ENCRYPTION_KEY:-$(openssl rand -hex 32)}"

# ─── Deploy (creates service automatically) ──────────────────

echo ""
info "Deploying TREK to Railway..."
info "This will build the Docker image and create the service."
echo ""

railway up --detach

success "Deployment triggered!"
echo ""

# ─── Wait for service to be available ────────────────────────

info "Waiting for service to register..."
sleep 5

# ─── Environment variables ───────────────────────────────────

info "Configuring environment variables..."

railway variables set \
  NODE_ENV=production \
  PORT=3000 \
  ENCRYPTION_KEY="$ENCRYPTION_KEY" \
  TZ="${TZ:-UTC}" \
  LOG_LEVEL="${LOG_LEVEL:-info}" \
  FORCE_HTTPS=true \
  TRUST_PROXY=1 \
  COOKIE_SECURE=true \
  2>/dev/null && success "Core variables set" \
  || warn "Could not set variables via CLI — set them in the Railway dashboard"

if [ -n "${ALLOWED_ORIGINS:-}" ]; then
  railway variables set ALLOWED_ORIGINS="$ALLOWED_ORIGINS" 2>/dev/null || true
else
  warn "ALLOWED_ORIGINS not set. After deployment, run:"
  warn "  railway variables set ALLOWED_ORIGINS=https://your-domain.com"
fi

if [ -n "${APP_URL:-}" ]; then
  railway variables set APP_URL="$APP_URL" 2>/dev/null || true
fi

if [ -n "${ADMIN_EMAIL:-}" ]; then
  railway variables set ADMIN_EMAIL="$ADMIN_EMAIL" 2>/dev/null || true
  [ -n "${ADMIN_PASSWORD:-}" ] && railway variables set ADMIN_PASSWORD="$ADMIN_PASSWORD" 2>/dev/null || true
fi

# ─── Persistent volumes ─────────────────────────────────────

echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}  IMPORTANT: Add persistent volumes in the Railway dashboard ${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "  Without volumes, ALL DATA IS LOST on redeploy."
echo ""
echo "  1. Open your project: https://railway.com"
echo "  2. Click the service → Settings → Volumes"
echo "  3. Add volume with mount path:  /app/data"
echo "  4. Add volume with mount path:  /app/uploads"
echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# ─── Summary ─────────────────────────────────────────────────

echo ""
success "Deployment in progress!"
echo ""
info "Monitor your deployment:"
echo "  railway logs"
echo "  railway status"
echo ""
info "Generate a public domain:"
echo "  railway domain"
echo ""
echo -e "${RED}  SAVE YOUR ENCRYPTION KEY — you need it if you ever migrate:${NC}"
echo "  $ENCRYPTION_KEY"
echo ""
info "After domain is assigned, set ALLOWED_ORIGINS:"
echo "  railway variables set ALLOWED_ORIGINS=https://your-domain.railway.app"
echo "  railway variables set APP_URL=https://your-domain.railway.app"
echo ""
success "Done!"
