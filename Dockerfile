##
# 1) Build/Installer Stage using Yarn
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

# Copy package manifests first for caching. 
# (Make sure you commit a yarn.lock file to your repo; if you don't have one, Yarn will generate one.)
COPY package.json yarn.lock* ./

# Install Yarn globally
RUN npm install -g yarn

# Install all dependencies using Yarn. --frozen-lockfile ensures consistency.
RUN yarn install --frozen-lockfile --network-concurrency 1 --verbose

# Copy the rest of the source code
COPY . /juice-shop

# Build the application (both frontend & server) and list the build directory for debugging
RUN yarn run build && ls -la /juice-shop/build

# (Optional) Remove dev dependencies – Yarn doesn't have a direct equivalent of npm prune,
# so in production we rely on a production install in the runtime stage.
RUN yarn install --production --frozen-lockfile

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

# Set working directory
WORKDIR /juice-shop

# Copy the built application from the installer stage
COPY --from=installer --chown=65532:0 /juice-shop .

# Switch to a non-root user provided by distroless
USER 65532

# Expose port 3000 (ensure your application listens on port 3000)
EXPOSE 3000

# Start the Node app. (Adjust if needed, e.g., ["node", "/juice-shop/build/app.js"])
CMD ["/juice-shop/build/app.js"]
