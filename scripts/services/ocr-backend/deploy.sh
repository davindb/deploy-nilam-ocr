#!/usr/bin/env bash
# Deploy OCR backend (api + worker) dari Nexus ke GKE.
#
# Usage:
#   ./deploy.sh ocr-backend <tag> [--env dev] [--dry-run] [-- <argumen helm tambahan>]
#
# Contoh:
#   ./deploy.sh ocr-backend ec05d54
#   ./deploy.sh ocr-backend ec05d54 --dry-run              # render manifest saja, tanpa cluster
#   ./deploy.sh ocr-backend ec05d54 --env shared           # cluster shared, lewat bastion
#   GKE_PROJECT=project-lain BACKEND_NAMESPACE=ocr-test ./deploy.sh ocr-backend ec05d54
#   ./deploy.sh ocr-backend ec05d54 -- --set autoscaling.worker.maxReplicas=8
source "$(dirname "${BASH_SOURCE[0]}")/../../_lib.sh"

parse_args "$@"
load_env
require BACKEND_RELEASE BACKEND_NAMESPACE BACKEND_IMAGE BACKEND_SECRET

NAMESPACE="$BACKEND_NAMESPACE"

APP_SECRET="$BACKEND_SECRET"
deploy_component "$BACKEND_RELEASE" ocr-backend "$BACKEND_IMAGE" --set "existingSecret=$BACKEND_SECRET"
