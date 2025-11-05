# Frontend Dockerfile for SIKA AI Assistant
# Multi-stage build: Build React app → Serve with Nginx

# ===== Stage 1: Build =====
FROM node:18-alpine AS builder

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci

# Copy source code
COPY . .

# Build arguments for environment variables
ARG VITE_WS_TEXT_URL
ARG VITE_WS_VOICE_URL

# Set environment variables for build
ENV VITE_WS_TEXT_URL=${VITE_WS_TEXT_URL}
ENV VITE_WS_VOICE_URL=${VITE_WS_VOICE_URL}

# Build production bundle
RUN npm run build

# ===== Stage 2: Production =====
FROM nginx:alpine

# Copy custom nginx config
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copy built assets from builder stage
COPY --from=builder /app/dist /usr/share/nginx/html

# Expose port
EXPOSE 80

# Start nginx
CMD ["nginx", "-g", "daemon off;"]
