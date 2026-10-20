#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<'USAGE'
Usage:
  ./deploy.sh ocr-backend <tag> [--env <env>] [--dry-run] [-- <helm args...>]
  ./deploy.sh rbac-ui <tag> [--env <env>] [--dry-run] [-- <helm args...>]
  ./deploy.sh redis <tag> [--env <env>] [--dry-run] [-- <helm args...>]
  ./deploy.sh application <backend-tag> <rbac-ui-tag> [--env <env>] [--dry-run]

'application' deploys the OCR backend first, then the RBAC UI.
Redis is deployed separately because it is shared infrastructure.
USAGE
}

if [[ $# -eq 0 || "$1" == "-h" || "$1" == "--help" ]]; then
  usage
  exit 0
fi

service="$1"
shift

case "$service" in
  ocr-backend)
    exec "$ROOT_DIR/scripts/services/ocr-backend/deploy.sh" "$@"
    ;;
  rbac-ui)
    exec "$ROOT_DIR/scripts/services/rbac-ui/deploy.sh" "$@"
    ;;
  redis)
    exec "$ROOT_DIR/scripts/services/redis/deploy.sh" "$@"
    ;;
  application)
    [[ $# -ge 2 ]] || { usage >&2; exit 2; }
    backend_tag="$1"
    rbac_ui_tag="$2"
    shift 2
    "$ROOT_DIR/scripts/services/ocr-backend/deploy.sh" "$backend_tag" "$@"
    "$ROOT_DIR/scripts/services/rbac-ui/deploy.sh" "$rbac_ui_tag" "$@"
    ;;
  *)
    printf 'Unknown service: %s\n\n' "$service" >&2
    usage >&2
    exit 2
    ;;
esac
