FROM node:22-bookworm-slim
WORKDIR /opt/postman
COPY postman/ci/package.json postman/ci/package-lock.json ./
RUN npm ci --ignore-scripts --omit=dev --no-audit --no-fund \
    && chmod -R a-w node_modules \
    && /opt/postman/node_modules/@postman/pm-bin-linux-x64/bin/postman --version \
    && mkdir -p /reports && chown node:node /reports
WORKDIR /tests
COPY postman/ci/ ./
USER node
CMD ["node", "run.mjs"]
