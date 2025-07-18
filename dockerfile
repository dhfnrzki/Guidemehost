# Pakai Flutter image resmi
FROM cirrusci/flutter:stable

# Set direktori kerja
WORKDIR /app

# Salin semua file ke container
COPY . .

# Ambil dependencies
RUN flutter pub get

# Build project untuk web
RUN flutter build web

# Pakai Python untuk serve hasil build
RUN apt-get update && apt-get install -y python3

EXPOSE 8080

# Jalankan web app Flutter
CMD ["python3", "-m", "http.server", "8080", "--directory", "build/web"]