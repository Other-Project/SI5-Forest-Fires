# Build the Rust application
FROM rust:1.92.0-alpine AS builder
WORKDIR /app
RUN apk update
RUN apk add libc-dev openssl-dev openssl-libs-static build-base musl-dev pkgconfig perl cmake

# Create a dummy project to cache dependencies
COPY Cargo.toml Cargo.lock ./
RUN mkdir src && echo "fn main() {}" > src/main.rs
RUN cargo build --release

# Copy the actual project files and rebuild
COPY . .
RUN cargo build --release

# Create a minimal runtime image
FROM scratch
USER 1000:1000
COPY --from=builder /app/target/release/pre-treatment /pre-treatment
ENTRYPOINT ["/pre-treatment"]
