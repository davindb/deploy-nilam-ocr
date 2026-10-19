#!/usr/bin/env bash
# Deploy RBAC admin UI dari Nexus ke GKE.
#
# Usage:
#   ./scripts/deploy-rbac-ui.sh <tag> [--env dev] [--dry-run] [-- <argumen helm tambahan>]
#
# Contoh:
#   ./scripts/deploy-rbac-ui.sh d25f1de
#   ./scripts/deploy-rbac-ui.sh d25f1de --dry-run
#   NAMESPACE=ocr-test ./scripts/deploy-rbac-ui.sh d25f1de
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

parse_args "$@"
load_env
require RBAC_UI_RELEASE RBAC_UI_IMAGE

deploy_component "$RBAC_UI_RELEASE" ocr-rbac-ui "$RBAC_UI_IMAGE"
