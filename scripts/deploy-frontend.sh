#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INFRA_DIR="$ROOT_DIR/infra"
DIST_DIR="$ROOT_DIR/dist"

if ! command -v aws >/dev/null 2>&1; then
  echo "Error: aws CLI no está instalado o no está en el PATH." >&2
  exit 1
fi

if ! command -v terraform >/dev/null 2>&1; then
  echo "Error: terraform no está instalado o no está en el PATH." >&2
  exit 1
fi

cd "$ROOT_DIR"
npm ci
npm run build

BUCKET_NAME="$(terraform -chdir="$INFRA_DIR" output -raw frontend_bucket_name)"
DISTRIBUTION_ID="$(terraform -chdir="$INFRA_DIR" output -raw frontend_cloudfront_distribution_id)"

if [[ ! -d "$DIST_DIR" ]]; then
  echo "Error: no existe $DIST_DIR. Ejecutá npm run build antes de desplegar." >&2
  exit 1
fi

aws s3 sync "$DIST_DIR/" "s3://$BUCKET_NAME" --delete
aws cloudfront create-invalidation --distribution-id "$DISTRIBUTION_ID" --paths "/*"

echo "Frontend desplegado en S3 y CloudFront."
