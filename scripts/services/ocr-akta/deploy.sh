#!/usr/bin/env bash
# Deploy satu service NILAM OCR akta dari Nexus ke GKE. Lima service, satu chart (charts/ocr-akta), satu release
# per service: $AKTA_RELEASE_PREFIX-<service>, image $AKTA_IMAGE_PREFIX-<service>.
#
# Usage:
#   ./deploy.sh ocr-akta-<service> <tag> [--env dev] [--dry-run] [-- <argumen helm tambahan>]
#   ./deploy.sh akta <tag> [--env dev] [--dry-run]        # kelimanya, tag yang sama
#
# service: orchestrator, extraction, guardrails, structuring, scoring
#
# Contoh:
#   ./deploy.sh ocr-akta-extraction eab7fc7
#   ./deploy.sh ocr-akta-extraction eab7fc7 --dry-run          # render manifest saja, tanpa cluster
#   ./deploy.sh ocr-akta-structuring eab7fc7 --env shared      # cluster shared, lewat bastion
#   AKTA_NAMESPACE=nilam-ocr-akta-test ./deploy.sh ocr-akta-scoring eab7fc7
source "$(dirname "${BASH_SOURCE[0]}")/../../_lib.sh"

AKTA_SERVICES="orchestrator extraction guardrails structuring scoring"

component="${1:-}"
case " $AKTA_SERVICES " in
  *" $component "*) shift ;;
  *)
    [[ "$component" == "-h" || "$component" == "--help" ]] && { usage; exit 0; }
    usage
    die "service akta tidak dikenal: '${component}' (pilih: ${AKTA_SERVICES// /, })"
    ;;
esac

parse_args "$@"
load_env
require AKTA_RELEASE_PREFIX AKTA_NAMESPACE AKTA_NEXUS_PATH AKTA_IMAGE_PREFIX AKTA_SECRET

NAMESPACE="$AKTA_NAMESPACE"
# Akta images have their own Nexus folder, not the orchestrator's NEXUS_PATH.
NEXUS_PATH="$AKTA_NEXUS_PATH"

APP_SECRET="$AKTA_SECRET"
deploy_component "$AKTA_RELEASE_PREFIX-$component" ocr-akta "$AKTA_IMAGE_PREFIX-$component" \
  --set "component=$component" --set "existingSecret=$AKTA_SECRET"
