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

# Set our working directory
WORKDIR /juice-shop

# Copy package manifests first (for better caching)
COPY package*.json ./

# Upgrade npm to version 11.2.0
RUN npm install -g npm@11.2.0

# Install all dependencies (including dev) so we can run the Angular build.
RUN npm install --unsafe-perm --legacy-peer-deps --force --loglevel silly

# Copy the rest of the source code
COPY . /juice-shop

# Build the application (frontend & server) and list the build directory for debugging
RUN npm run build && ls -la /juice-shop/build

# Remove dev dependencies to minimize final image size
RUN npm prune --omit=dev
RUN npm dedupe

# Remove unneeded folders and files
RUN rm -rf frontend/node_modules \
           frontend/.angular \
           frontend/src/assets
RUN mkdir logs
RUN chown -R 65532 logs
RUN chgrp -R 0 ftp/ frontend/dist/ logs/ data/ i18n/
RUN chmod -R g=u ftp/ frontend/dist/ logs/ data/ i18n/
RUN rm data/chatbot/botDefaultTrainingData.json || true
RUN rm ftp/legal.md || true
RUN rm i18n/*.json || true

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

# Set the working directory
WORKDIR /juice-shop

# Copy everything from the build stage, preserving ownership for non-root user
COPY --
