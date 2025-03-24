##
# 1) Build/Installer Stage
##
FROM node:18 as installer

# Install build tools (python3, make, g++) for native modules
RUN apt-get update && apt-get install -y \
    python3 \
    make \
    g++ \
  && rm -rf /var/lib/apt/lists/*

# Set our working directory
WORKDIR /juice-shop

# Copy package manifests first (for caching)
COPY package*.json ./

# Upgrade npm to the latest recommended version (11.2.0)
RUN npm install -g npm@11.2.0

# Install all dependencies (including dev) so we can run the Angular build.
# Using --unsafe-perm, --legacy-peer-deps, and --force for installation.
RUN npm install --unsafe-perm --legacy-peer-deps --force --loglevel silly

# Copy the rest of the source code
COPY . /juice-shop

# Build the application (frontend & server)
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

# Optional ARGs for metadata
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

# Set our working directory (same as in the build stage)
WORKDIR /juice-shop

# Copy built application from the installer stage, preserving ownership
COPY --from=installer --chown=65532:0 /juice-shop .

# Use a non-root user from distroless
USER 65532

# Expose port 3000 by default (ensure your application listens on port 3000)
EXPOSE 3000

# Start the Node app (adjust if needed; you can use "node" explicitly if required)
CMD ["/juice-shop/build/app.js"]
