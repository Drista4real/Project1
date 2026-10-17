FROM node:22-bookworm-slim
RUN npm install --global postman-cli@1.75.0 \
    && mkdir -p /reports && chown node:node /reports
WORKDIR /tests
COPY postman/ci/ ./
USER node
CMD ["node", "run.mjs"]
