##
# 1) Build/Installer Stage
##
FROM node:18-bullseye as installer

# Install build tools for native modules
RUN apt-get update && apt-get install -y \
    python3 \
    make \
    g++ \
  && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /juice-shop

# Copy package manifests first (for caching)
COPY package.json ./
# Optionally, if you have one, copy package-lock.json or yarn.lock:
# COPY package-lock.json ./

# Set environment variables to force legacy peer dependency resolution and disable update notifications.
ENV npm_config_legacy_peer_deps=true
ENV npm_config_update_notifier=false
ENV npm_config_loglevel=verbose

# Install dependencies
RUN npm install --unsafe-perm

# Copy the rest of the source code
COPY . /juice-shop

# Build the application (frontend & server) and list the build directory for debugging
RUN npm run build && ls -la /juice-shop/build

# Remove dev dependencies and dedupe
RUN npm prune --omit=dev && npm dedupe

# Remove unneeded folders and files to reduce image size
RUN rm -rf frontend/node_modules frontend/.angular frontend/src/assets && \
    mkdir logs && \
    chown -R 65532 logs && \
    chgrp -R 0 ftp/ frontend/dist/ logs/ data/ i18n/ && \
    chmod -R g=u ftp/ frontend/dist/ logs/ data/ i18n/ && \
    rm data/chatbot/botDefaultTrainingData.json || true && \
    rm ftp/legal.md || true && \
    rm i18n/*.json || true

##
# 2) Production Runtime Stage
##
FROM gcr.io/distroless/nodejs:18

# Optional build metadata
ARG BUILD_DATE
ARG VCS_REF
LABEL maintainer="Bjoern Kimminich <bjoern.kimminich@owasp.org>" \
      org.opencontainers.image.title="OWASP Juice Shop" \
      org.opencontainers.image.description="Probably the most modern and sophisticated insecure web application" \
      org.opencontainers.image.authors="Bjoern Kimminich <bjoern.kimminich@owasp.org>" \
      org.opencontainers.image.vendor="Open Web Application Security Project" \
      org.opencontainers.image.documentation="https://help.owasp-juice.shop" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.version="15.0.0" \
      org.opencontainers.image.url="https://owasp-juice.shop" \
      org.opencontainers.image.source="https://github.com/juice-shop/juice-shop" \
      org.opencontainers.image.revision=$VCS_REF \
      org.opencontainers.image.created=$BUILD_DATE

# Set working directory in production stage
WORKDIR /juice-shop

# Copy built application from installer stage, preserving ownership for non-root user
COPY --from=installer --chown=65532:0 /juice-shop .

# Switch to a non-root user provided by distroless
USER 65532

# Expose port 3000 (make sure your app listens on port 3000)
EXPOSE 3000

# Start the Node application.
# If your app.js file requires Node explicitly, you may change the CMD to:
# CMD ["node", "/juice-shop/build/app.js"]
CMD ["/juice-shop/build/app.js"]
