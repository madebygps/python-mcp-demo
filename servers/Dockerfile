# ------------------- Stage 1: Build Stage ------------------------------
# We use Alpine for smaller image size (~329MB vs ~431MB for Debian slim).
# Trade-off: We must install build tools to compile native extensions (cryptography, etc.)
# since pre-built musl wheels aren't available. Debian -slim would skip compilation
# but produces a larger final image due to glibc wheel sizes.
FROM python:3.13-alpine AS build

# Install build dependencies for packages with native extensions (cryptography, etc.)
# https://cryptography.io/en/latest/installation/#building-cryptography-on-linux
RUN apk add --no-cache gcc g++ musl-dev python3-dev libffi-dev openssl-dev cargo pkgconfig

COPY --from=ghcr.io/astral-sh/uv:0.9.14 /uv /uvx /bin/

WORKDIR /code

# Install dependencies first (for layer caching)
RUN --mount=type=cache,target=/root/.cache/uv \
    --mount=type=bind,source=uv.lock,target=uv.lock \
    --mount=type=bind,source=pyproject.toml,target=pyproject.toml \
    uv sync --locked --no-install-project

# Copy the project and sync
COPY . .
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --locked

# ------------------- Stage 2: Final Stage ------------------------------
FROM python:3.13-alpine AS final

RUN addgroup -S app && adduser -S app -G app

COPY --from=build --chown=app:app /code /code

WORKDIR /code/servers
USER app

ENV PATH="/code/.venv/bin:$PATH"

EXPOSE 8000

ENTRYPOINT ["uvicorn", "deployed_mcp:app", "--host", "0.0.0.0", "--port", "8000"]

# many customers are using stdio servers, you can either wrap them with stdio->sse adapter
# or use MCP toolkit / MCP-gateway (requires docker socket access - priveleged mode, which you cant get on SSE)
# https://github.com/sparfenyuk/mcp-proxy

# examples using mcp-gateway:
# https://github.com/docker/compose-for-agents/commit/2314180bc5d1f056964a14361f73d2b8f5c247c3

# use az CLI or console to login to the agent container and run the agent
# https://github.com/modelcontextprotocol/servers/blob/main/src/time/README.md - wrapped version available
# Agent can make a report based off fetch_expenses tool and store in cosmos reports container