# Build Stage
FROM node:20-slim AS build

WORKDIR /app

COPY package*.json ./
RUN npm install

COPY . .

# Accept build argument for socket URL
ARG VITE_SOCKET_URL
ENV VITE_SOCKET_URL=$VITE_SOCKET_URL

RUN npm run build

# Production Stage - Serve with Nginx
FROM nginx:stable-alpine

COPY --from=build /app/dist /usr/share/nginx/html

# Replace default config to handle SPA routing if necessary
# For now, we'll use standard nginx hosting

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
