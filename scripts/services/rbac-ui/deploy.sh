#!/usr/bin/env bash
# Deploy RBAC admin UI dari Nexus ke GKE.
#
# Usage:
#   ./deploy.sh rbac-ui <tag> [--env dev] [--dry-run] [-- <argumen helm tambahan>]
#
# Contoh:
#   ./deploy.sh rbac-ui d25f1de
#   ./deploy.sh rbac-ui d25f1de --dry-run
#   ./deploy.sh rbac-ui d25f1de --env shared
#   RBAC_UI_NAMESPACE=ocr-test ./deploy.sh rbac-ui d25f1de
source "$(dirname "${BASH_SOURCE[0]}")/../../_lib.sh"

parse_args "$@"
load_env
require RBAC_UI_RELEASE RBAC_UI_NAMESPACE RBAC_UI_IMAGE BACKEND_NAMESPACE

NAMESPACE="$RBAC_UI_NAMESPACE"
# nginx proxies to the backend Service, which may live in another namespace.
deploy_component "$RBAC_UI_RELEASE" ocr-rbac-ui "$RBAC_UI_IMAGE" --set "backend.namespace=$BACKEND_NAMESPACE"
