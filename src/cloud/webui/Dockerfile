# Build the web UI with Vite
FROM oven/bun:1 AS builder
WORKDIR /app

COPY package.json bun.lock ./
RUN bun install --frozen-lockfile --production

ENV NODE_ENV=production
COPY . ./
RUN bun run build

# Serve the built web UI with a static web server
FROM joseluisq/static-web-server:2.40.1
USER server
COPY --from=builder /app/dist /public
