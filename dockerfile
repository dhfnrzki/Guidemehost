# Menggunakan image Flutter resmi versi stabil
FROM ghcr.io/cirruslabs/flutter:3.19.0

# Menentukan direktori kerja
WORKDIR /app

# Menyalin semua file project ke container
COPY . .

# Mengambil dependensi Flutter
RUN flutter pub get

# Membangun aplikasi Flutter Web
RUN flutter build web

# Menentukan direktori hasil build web
WORKDIR /app/build/web

# Menjalankan web server ringan (opsional jika diperlukan)
# Kamu bisa menggunakan web server seperti dhttpd, nginx, atau Python
CMD ["python3", "-m", "http.server", "8080"]
