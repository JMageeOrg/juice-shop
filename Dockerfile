
##
# 1) Build/Installer Stage
##
FROM node:18-bullseye as installer

# Install build tools (python3, make, g++) for native modules
RUN apt-get update && apt-get install -y \
    python3 \
    make \
    g++ \
  && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /juice-shop

# Copy package manifests first (for caching)
COPY package*.json ./

# Install all dependencies (including dev) so we can run the Angular build.
# Running npm install with --ignore-scripts to bypass postinstall issues.
RUN npm install --unsafe-perm --ignore-scripts --legacy-peer-deps --loglevel verbose

# Copy the rest of the source code
COPY . /juice-shop

# Run the build command; removed '|| true' so that build errors are not masked.
RUN npm run build

# (Optional) Debug step: list the build directory to verify output exists.
# RUN ls -la /juice-shop/build

# Remove dev dependencies to minimize final image size, then dedupe.
RUN npm prune --omit=dev && npm dedupe

# Remove unneeded folders and files
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

# Set working directory
WORKDIR /juice-shop

# Copy the built application from the installer stage, preserving ownership for non-root user
COPY --from=installer --chown=65532:0 /juice-shop .

# Use a non-root user provided by the distroless image
USER 65532

# Expose port 3000 (ensure your application listens on port 3000)
EXPOSE 3000

# Start the Node app explicitly using the node binary
CMD ["node", "/juice-shop/build/app.js"]
