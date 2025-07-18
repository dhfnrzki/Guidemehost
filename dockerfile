# Build stage: Membangun aplikasi Flutter
FROM cirrusci/flutter:stable AS build

WORKDIR /app
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get
COPY . .
RUN flutter build web --release

# Serve stage: Menggunakan Nginx untuk melayani aplikasi
FROM nginx:stable-alpine AS serve

COPY nginx.conf /etc/nginx/nginx.conf
COPY --from=build /app/build/web /usr/share/nginx/html

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]