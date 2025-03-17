# ------------------------------------------------------------------------------
# Builder Stage
# ------------------------------------------------------------------------------
FROM golang:1.22-bullseye AS build

# Set default build argument for CGO_ENABLED
ARG CGO_ENABLED=0
ENV CGO_ENABLED ${CGO_ENABLED}

WORKDIR /build

COPY go.mod go.sum ./
RUN go mod download
COPY Makefile main.go ./
COPY static/ static/
COPY pkg/ pkg/
COPY .git/ ./git/ || true
RUN make build

# ------------------------------------------------------------------------------
# Release Stage
# ------------------------------------------------------------------------------
FROM debian:bullseye-slim

# Install PostgreSQL client and other dependencies in a single layer
# Use the official PostgreSQL packages repository with explicit verification
RUN apt-get update && \
    apt-get install -y --no-install-recommends wget gnupg lsb-release ca-certificates && \
    wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - && \
    echo "deb http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends postgresql-client netcat curl && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

COPY --from=build /build/pgweb /usr/bin/pgweb

# Create a non-root user
RUN useradd --uid 1000 --no-create-home --shell /bin/false pgweb
USER pgweb

EXPOSE 8081
ENTRYPOINT ["/usr/bin/pgweb", "--bind=0.0.0.0", "--listen=8081"]
