#!/usr/bin/env bash
# Pin every FROM image in the Dockerfile to its current @sha256 digest.
# Renovate does the same thing automatically (and keeps the digests fresh).
set -euo pipefail
cd "$(dirname "$0")/.."

for image in $(awk '/^FROM /{print $2}' Dockerfile | grep -v '@' | sort -u); do
  digest=$(docker buildx imagetools inspect "$image" --format '{{.Manifest.Digest}}')
  IMG="$image" DIG="$digest" perl -pi -e 's#^FROM \Q$ENV{IMG}\E(?=\s|$)#FROM $ENV{IMG}\@$ENV{DIG}#' Dockerfile
  echo "Pinned $image@$digest"
done
