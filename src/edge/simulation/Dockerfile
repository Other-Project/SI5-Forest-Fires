FROM python:3.12-alpine AS builder

# Install build tools
RUN apk add --no-cache build-base

# Install uv
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

WORKDIR /app

# Compiles .pyc files (faster startup)
ENV UV_COMPILE_BYTECODE=1
# Ensures files are copied, not hardlinked (safer for Docker)
ENV UV_LINK_MODE=copy

# Install dependencies
COPY pyproject.toml uv.lock ./

# --frozen: strict lockfile adherence
# --no-dev: production deps only
# --no-install-project: deps only, not code
RUN uv sync --frozen --no-dev --no-install-project



FROM python:3.12-alpine
WORKDIR /app
COPY --from=builder --chown=1000:1000 /app/.venv /app/.venv
COPY --chown=1000:1000 . .
ENV PATH="/app/.venv/bin:$PATH"
ENV PLOT="False"

USER 1000:1000
CMD ["python", "main.py"]