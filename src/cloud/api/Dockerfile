# Use cargo-chef to cache dependencies and speed up builds
FROM lukemathwalker/cargo-chef:latest-rust-1.92-alpine AS chef
RUN apk add --no-cache libc-dev openssl-dev openssl-libs-static build-base musl-dev pkgconfig perl cmake
WORKDIR /app

# Generate the recipe file
FROM chef AS planner
COPY . .
COPY --from=shared . /utils/rust_shared/
RUN cargo chef prepare --recipe-path recipe.json

FROM chef AS builder
# Build the dependencies specified in the recipe file
COPY --from=planner /app/recipe.json recipe.json
COPY --from=shared . /utils/rust_shared/
RUN cargo chef cook --release --target x86_64-unknown-linux-musl --recipe-path recipe.json
# Build the application
COPY . .
ENV OPENSSL_STATIC=1
RUN cargo build --release --target x86_64-unknown-linux-musl

# Create the final lightweight image
FROM scratch
USER 1000:1000
COPY --from=builder /app/target/x86_64-unknown-linux-musl/release/api /api
ENTRYPOINT ["/api"]
