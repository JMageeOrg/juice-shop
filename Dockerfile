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
COPY package*.json ./

# Install all dependencies but ignore scripts (to bypass the failing postinstall)
RUN npm install --unsafe-perm --ignore-scripts --legacy-peer-deps --loglevel verbose

# Copy the rest of the source code
COPY . /juice-shop

# Manually run the build commands defined in package.json
# (This runs "npm run build:frontend && npm run build:server")
RUN npm run build

# Remove dev dependencies to minimize final image size, then dedupe
RUN npm prune --omit=dev && npm dedupe

# Clean up unneeded folders and files
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

# Copy the built application from the installer stage
COPY --from=installer --chown=65532:0 /juice-shop .

# Switch to a non-root user provided by distroless
USER 65532

# Expose port 3000 (your application should listen on port 3000)
EXPOSE 3000

# Start the application.
# If needed, change to ["node", "/juice-shop/build/app.js"] if the script isn't executable directly.
CMD ["/juice-shop/build/app.js"]
