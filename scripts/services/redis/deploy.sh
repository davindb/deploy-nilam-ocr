#!/usr/bin/env bash
# Deploy Redis (antrean job OCR + cache) dari Nexus ke GKE.
#
# Usage:
#   ./deploy.sh redis <tag> [--env shared] [--dry-run] [-- <argumen helm tambahan>]
#
# Contoh:
#   ./deploy.sh redis 7.4.7-alpine --env shared
#   ./deploy.sh redis 7.4.7-alpine --env shared --dry-run
source "$(dirname "${BASH_SOURCE[0]}")/../../_lib.sh"

parse_args "$@"
load_env
require REDIS_RELEASE REDIS_NAMESPACE REDIS_IMAGE REDIS_SECRET

NAMESPACE="$REDIS_NAMESPACE"
APP_SECRET="$REDIS_SECRET"
deploy_component "$REDIS_RELEASE" redis "$REDIS_IMAGE" --set "existingSecret=$REDIS_SECRET"
