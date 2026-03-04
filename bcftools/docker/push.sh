#!/bin/bash

set -ex

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BCFTOOLS_VERSION="1.23"
HTSLIB_VERSION="1.23"
PUSH_TAG="us-docker.pkg.dev/broad-dsde-methods/bcftools-patched/bcftools:$BCFTOOLS_VERSION"

docker buildx build \
    --build-arg BCFTOOLS_VERSION="$BCFTOOLS_VERSION" \
    --build-arg HTSLIB_VERSION="$HTSLIB_VERSION" \
    -t "${PUSH_TAG}" \
    --platform linux/amd64 \
    --push \
    "$SCRIPT_DIR"
