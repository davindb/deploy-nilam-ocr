#!/usr/bin/env bash
# Test Bedrock API access from a temporary pod in GKE; this checks AWS auth and bedrock:ListFoundationModels.
#
# Usage:
#   ./scripts/services/bedrock/test-connectivity.sh [--env shared] [--region <aws-region>]
#
# The Kubernetes Secret $BEDROCK_SECRET must provide AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY; also set
# AWS_SESSION_TOKEN for temporary credentials. Region comes from --region, BEDROCK_REGION, AWS_REGION, or
# AWS_DEFAULT_REGION, otherwise the Secret must provide AWS_REGION/AWS_DEFAULT_REGION.
source "$(dirname "${BASH_SOURCE[0]}")/../../_lib.sh"

DEPLOY_ENV="${DEPLOY_ENV:-shared}"
BEDROCK_REGION_ARG=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -e|--env) [[ $# -ge 2 ]] || die "--env butuh nilai"; DEPLOY_ENV="$2"; shift 2 ;;
    -r|--region) [[ $# -ge 2 ]] || die "--region butuh nilai"; BEDROCK_REGION_ARG="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) die "opsi tidak dikenal: $1" ;;
  esac
done

load_env
[[ "$DEPLOY_ENV" == "shared" ]] || die "tes Bedrock hanya dikonfigurasi untuk --env shared"
require BEDROCK_NAMESPACE BEDROCK_SECRET

BEDROCK_REGION="${BEDROCK_REGION_ARG:-${BEDROCK_REGION:-${AWS_REGION:-${AWS_DEFAULT_REGION:-}}}}"
[[ -z "$BEDROCK_REGION" || "$BEDROCK_REGION" =~ ^[a-z]{2}(-[a-z]+)+-[0-9]+$ ]] \
  || die "format region AWS tidak valid: $BEDROCK_REGION"
[[ "$BEDROCK_NAMESPACE" =~ ^[a-z0-9]([-a-z0-9]*[a-z0-9])?$ ]] || die "nama namespace Kubernetes tidak valid: $BEDROCK_NAMESPACE"
[[ "$BEDROCK_SECRET" =~ ^[a-z0-9]([-a-z0-9]*[a-z0-9])?$ ]] || die "nama Secret Kubernetes tidak valid: $BEDROCK_SECRET"

BEDROCK_TEST_IMAGE="${BEDROCK_TEST_IMAGE:-public.ecr.aws/aws-cli/aws-cli:2}"
[[ "$BEDROCK_TEST_IMAGE" =~ ^[A-Za-z0-9][A-Za-z0-9./:_@-]*$ ]] || die "nama image probe tidak valid: $BEDROCK_TEST_IMAGE"

need_tools gcloud kubectl
NAMESPACE="$BEDROCK_NAMESPACE"
gke_connect
kc get namespace "$NAMESPACE" >/dev/null 2>&1 || die "namespace $NAMESPACE belum ada di GKE"
kc get secret "$BEDROCK_SECRET" >/dev/null 2>&1 \
  || die "Secret $BEDROCK_SECRET belum ada di namespace $NAMESPACE"


POD="bedrock-connectivity-$RANDOM-$RANDOM"
CONTAINER="bedrock-test"
AWS_ARGS='["bedrock","list-foundation-models","--query","length(modelSummaries)","--output","text"]'
AWS_REGION_ENV=""
if [[ -n "$BEDROCK_REGION" ]]; then
  AWS_ARGS="$(printf '["bedrock","list-foundation-models","--region","%s","--query","length(modelSummaries)","--output","text"]' \
    "$BEDROCK_REGION")"
  AWS_REGION_ENV="$(printf '{"name":"AWS_REGION","value":"%s"},{"name":"AWS_DEFAULT_REGION","value":"%s"},' \
    "$BEDROCK_REGION" "$BEDROCK_REGION")"
fi
OVERRIDES="$(printf '{"apiVersion":"v1","spec":{"containers":[{"name":"%s","image":"%s","imagePullPolicy":"IfNotPresent","resources":{"requests":{"cpu":"100m","memory":"128Mi"},"limits":{"cpu":"400m","memory":"384Mi"}},"command":["aws"],"args":%s,"envFrom":[{"secretRef":{"name":"%s"}}],"env":[%s{"name":"AWS_PAGER","value":""},{"name":"AWS_MAX_ATTEMPTS","value":"1"}]}]}}' \
  "$CONTAINER" "$BEDROCK_TEST_IMAGE" "$AWS_ARGS" "$BEDROCK_SECRET" "$AWS_REGION_ENV")"

AWS_REGION_LABEL="${BEDROCK_REGION:-dari Secret}"
log "Uji AWS Bedrock dari GKE: namespace=$NAMESPACE region=$AWS_REGION_LABEL"
MODEL_COUNT="$(kc run "$POD" \
  --image="$BEDROCK_TEST_IMAGE" \
  --restart=Never \
  --attach --rm --quiet \
  --pod-running-timeout=90s \
  --overrides="$OVERRIDES")"
log "Koneksi Bedrock berhasil; $MODEL_COUNT foundation model terlihat di $AWS_REGION_LABEL."
