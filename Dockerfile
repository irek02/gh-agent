FROM node:18-alpine

WORKDIR /app

RUN apk add --no-cache git

COPY package*.json ./
RUN npm ci --only=production

COPY . .

RUN mkdir -p /app/target-repo && \
    mkdir -p /app/logs

VOLUME ["/app/target-repo", "/app/logs", "/app/processed_issues.json"]

USER node

CMD ["npm", "start"]