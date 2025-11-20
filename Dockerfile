# Stage 1: Build Flutter Web
FROM ghcr.io/cirruslabs/flutter:stable AS build

# Directorul de lucru in container
WORKDIR /app

# Copiem fisierele de dependinte
COPY pubspec.yaml pubspec.lock ./

# Instalam dependintele
RUN flutter pub get

# Copiem restul codului sursa
COPY . .

# Ne asiguram ca suportul pentru web este activ
RUN flutter config --enable-web

# Build pentru web (production)
# Dezactivam wasm dry run ca sa nu te inunde cu warning-uri
RUN flutter build web --release --no-wasm-dry-run

# Stage 2: Serve with Nginx
FROM nginx:alpine

# Copiem build-ul generat de Flutter in root-ul Nginx
COPY --from=build /app/build/web /usr/share/nginx/html

# Config Nginx pentru Flutter Web (SPA)
RUN echo 'server { \
    listen 80; \
    server_name _; \
    root /usr/share/nginx/html; \
    location / { \
    try_files $uri $uri/ /index.html; \
    } \
    }' > /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
