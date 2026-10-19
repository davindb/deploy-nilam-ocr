#!/usr/bin/env bash
# Deploy OCR backend (api + worker) dari Nexus ke GKE.
#
# Usage:
#   ./scripts/deploy-ocr-backend.sh <tag> [--env dev] [--dry-run] [-- <argumen helm tambahan>]
#
# Contoh:
#   ./scripts/deploy-ocr-backend.sh ec05d54
#   ./scripts/deploy-ocr-backend.sh ec05d54 --dry-run              # render manifest saja, tanpa cluster
#   GKE_PROJECT=project-lain ./scripts/deploy-ocr-backend.sh ec05d54
#   ./scripts/deploy-ocr-backend.sh ec05d54 -- --set autoscaling.worker.maxReplicas=8
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

parse_args "$@"
load_env
require BACKEND_RELEASE BACKEND_IMAGE BACKEND_SECRET

APP_SECRET="$BACKEND_SECRET"
deploy_component "$BACKEND_RELEASE" ocr-backend "$BACKEND_IMAGE" --set "existingSecret=$BACKEND_SECRET"
