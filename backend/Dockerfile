# Stage 1: Builder
FROM node:20-alpine AS builder

WORKDIR /usr/src/app

# Install build dependencies
RUN apk add --no-cache python3 make g++

# Copy package files
COPY package*.json ./
COPY tsconfig*.json ./

# Install all dependencies including devDependencies for build
RUN npm ci

# Copy source code
COPY . .

# Build NestJS application
RUN npm run build

# Prune dev dependencies for production
RUN npm prune --production

# Stage 2: Production runtime
FROM node:20-alpine AS runner

WORKDIR /usr/src/app

# Install dumb-init or required runtime utilities
RUN apk add --no-cache curl postgresql-client

# Create non-root user
USER node

# Copy built application and production dependencies from builder stage
COPY --chown=node:node --from=builder /usr/src/app/package*.json ./
COPY --chown=node:node --from=builder /usr/src/app/node_modules ./node_modules
COPY --chown=node:node --from=builder /usr/src/app/dist ./dist

# Copy database migrations / schema if needed
COPY --chown=node:node --from=builder /usr/src/app/src/database ./dist/database

ENV NODE_ENV=production
ENV PORT=3000

EXPOSE 3000

CMD ["node", "dist/main.js"]
