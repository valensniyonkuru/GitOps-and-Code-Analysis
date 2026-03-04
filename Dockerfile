# Multi-stage Dockerfile - Secure Production Build

FROM node:18-slim AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production && npm cache clean --force
COPY . .

FROM node:18-slim AS production
ARG APP_VERSION=1.0.0
ARG BUILD_DATE
ARG GIT_COMMIT

LABEL maintainer="DevOps Team" \
    version="${APP_VERSION}" \
    description="Secure Web Application"

RUN apt-get update && apt-get upgrade -y && \
    apt-get install -y --no-install-recommends curl dumb-init && \
    apt-get clean && rm -rf /var/lib/apt/lists/* && \
    groupadd -r nodejs && useradd -r -g nodejs nodejs

WORKDIR /app
COPY --from=builder --chown=nodejs:nodejs /app/node_modules ./node_modules
COPY --chown=nodejs:nodejs package*.json app.js index.js ./
COPY --chown=nodejs:nodejs routes ./routes
COPY --chown=nodejs:nodejs models ./models

ENV NODE_ENV=production PORT=3000 APP_VERSION=${APP_VERSION}
EXPOSE 3000
USER nodejs

HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
    CMD curl -f http://localhost:3000/ || exit 1

ENTRYPOINT ["/usr/bin/dumb-init", "--"]
CMD ["node", "index.js"]
