# Build Stage
FROM node:20-slim AS build

WORKDIR /app

COPY package*.json ./
RUN npm install

COPY . .
RUN npm run build

# Production Stage
FROM node:20-slim

WORKDIR /app

# Only copy production dependencies
COPY package*.json ./
RUN npm install --only=production

# Copy built files from previous stage
COPY --from=build /app/dist ./dist

# The standard port for our server
EXPOSE 3001

# The start script for our server
CMD ["node", "dist/index.js"]
