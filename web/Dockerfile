# syntax=docker/dockerfile:1.7
#
# The marketing site as a standalone Next server on port 3000. Build context is
# web/. Needs no env vars or secrets: the site has none, and its public address
# defaults to production.
#
#   docker build -t remotely-web web
#   docker run --rm -p 3100:3000 remotely-web
#
# Production images are built by .github/workflows/deploy-web.yml (docs/hosting.md).

ARG NODE_VERSION=24

FROM node:${NODE_VERSION}-alpine AS builder
WORKDIR /src
COPY package.json package-lock.json ./
RUN --mount=type=cache,target=/root/.npm npm ci --no-audit --no-fund
COPY . .
# public/ is empty and untracked; a fresh checkout has no such folder.
RUN mkdir -p public
# Canonical links, the sitemap and robots.txt are prerendered with this
# address, so it is fixed at build time. Override it for another host.
ARG NEXT_PUBLIC_SITE_URL=https://remotely.newy.my
RUN case "$NEXT_PUBLIC_SITE_URL" in https://*) ;; *) echo "NEXT_PUBLIC_SITE_URL must start with https:// (got: $NEXT_PUBLIC_SITE_URL)" >&2; exit 1 ;; esac
ENV NEXT_TELEMETRY_DISABLED=1 NEXT_OUTPUT_STANDALONE=1 NEXT_PUBLIC_SITE_URL=${NEXT_PUBLIC_SITE_URL}
RUN npm run build && \
    find .next -name '.env*' -type f -delete && \
    ! find .next -name '.env*' | grep -q .

FROM node:${NODE_VERSION}-alpine AS runner
RUN apk add --no-cache tini
RUN addgroup -S -g 1001 nodejs && adduser -S -u 1001 -G nodejs nextjs
WORKDIR /app
ENV NODE_ENV=production \
    NEXT_TELEMETRY_DISABLED=1 \
    PORT=3000 \
    HOSTNAME=0.0.0.0 \
    TZ=UTC
COPY --from=builder --chown=nextjs:nodejs /src/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /src/.next/static ./.next/static
COPY --from=builder --chown=nextjs:nodejs /src/public ./public
USER nextjs
EXPOSE 3000
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD wget -q -O /dev/null http://127.0.0.1:3000/api/health || exit 1
# tini forwards SIGTERM to node, so in-flight requests finish on stop.
ENTRYPOINT ["/sbin/tini", "--"]
CMD ["node", "server.js"]
