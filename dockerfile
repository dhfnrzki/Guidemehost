# Gunakan image Flutter resmi
FROM cirrusci/flutter:stable

# Set working directory
WORKDIR /app

# Copy semua file project
COPY . .

# Jalankan pub get
RUN flutter pub get

# Build untuk web
RUN flutter build web

# Gunakan web server ringan untuk serve hasil build
RUN apt-get update && apt-get install -y python3

# Port Railway default
EXPOSE 8080

# Jalankan web app
CMD ["python3", "-m", "http.server", "8080", "--directory", "build/web"]