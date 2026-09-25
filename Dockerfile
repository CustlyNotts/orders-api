# syntax=docker/dockerfile:1
#
# The "after" Dockerfile from the talk.
# Base images are pinned by tag here; Renovate ("docker:pinDigests" in
# renovate.json) opens a PR that pins them to @sha256 digests, or run
# scripts/pin-digests.sh to do it yourself.

# Build stage: has npm, never ships.
FROM node:24-slim@sha256:0e0ff40c39bc087845bfb27465a0df4ea419520094bc35842ff83dd8cbe6f9b6 AS build
WORKDIR /app
COPY package.json package-lock.json ./
# Production dependencies only, exactly as locked. The app has no
# dependencies today; mkdir keeps the COPY below working either way.
RUN npm ci --omit=dev && mkdir -p node_modules
COPY src/ ./src/
# Make the app readable (not writable) by everyone, whatever permissions the
# files had on the build machine. Without this, a file saved as owner-only
# (rw-------) stays unreadable to the non-root user and the app can't start.
RUN chmod -R u=rwX,go=rX /app

# Runtime stage: no shell, no package manager, runs as UID 65532.
# Debian 13 base: distroless stopped building Debian 12 images in Sept 2026,
# so those no longer get security fixes.
FROM gcr.io/distroless/nodejs22-debian13:nonroot
WORKDIR /app
ENV NODE_ENV=production
# No --chown: files stay owned by root, so the app can read its code but
# not change it.
COPY --from=build /app/node_modules ./node_modules
COPY --from=build /app/src ./src
USER 65532:65532
EXPOSE 3000
CMD ["src/server.js"]
