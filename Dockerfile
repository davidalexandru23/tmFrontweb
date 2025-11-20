# Stage 1: Build Flutter Web
FROM ghcr.io/cirruslabs/flutter:stable AS build

# Setăm directorul de lucru
WORKDIR /app

# Copiem fișierele de dependențe
COPY pubspec.yaml pubspec.lock ./

# Instalăm dependențele
RUN flutter pub get

# Copiem restul aplicației
COPY . .

# Ne asigurăm că web e activat (nu strică, chiar dacă e deja)
RUN flutter config --enable-web

# Build pentru web (production)
# Atenție: fără --web-renderer, pentru că în versiunea asta de Flutter nu există flag-ul
RUN flutter build web --release

# Stage 2: Serve with Nginx
FROM nginx:alpine

# Copiem build-ul în root-ul Nginx
COPY --from=build /app/build/web /usr/share/nginx/html

# Config Nginx pentru single-page app Flutter Web
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
