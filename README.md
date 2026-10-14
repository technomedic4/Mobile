# SIMRS Sehat — aplikasi pasien

Aplikasi Flutter ini terhubung ke backend Laravel yang juga digunakan portal web
di [backend](./backend). Kedua aplikasi membaca dan menulis data pasien serta
pendaftaran pada database rumah sakit yang sama; aplikasi mobile tidak lagi
menggunakan akun demo atau data contoh lokal.

## Menjalankan backend API lokal

Jalankan API Laravel dari folder `backend` supaya emulator Android dan browser
di komputer dapat mengakses server:

```powershell
cd backend
composer install
php artisan serve --host=0.0.0.0 --port=8000
```

Pastikan `.env` backend sudah menunjuk ke database portal yang benar dan migrasi
yang diperlukan sudah diterapkan.

## Menjalankan aplikasi mobile dan web

1. Siapkan backend Laravel dan database yang dipakai portal web. Pastikan migrasi
   portal web yang sudah ada telah diterapkan sebelum menerapkan migrasi mobile.
2. Untuk development lokal, alamat API otomatis diarahkan ke
   `http://10.0.2.2:8000/api/v1` pada emulator Android dan
   `http://localhost:8000/api/v1` pada web/perangkat desktop.
3. Buka terminal kedua di root project (`Mobile-project`), lalu ambil dependency
   dan jalankan target yang diperlukan:

   ```powershell
   flutter pub get
   flutter run
   ```

   Untuk web, origin lokal sudah diizinkan CORS secara default:

   ```powershell
   flutter run -d chrome --web-port=5000
   ```

Untuk HP Android fisik, gunakan IP LAN komputer yang menjalankan backend dan
pastikan firewall mengizinkan port 8000:

```powershell
flutter run --dart-define=SIMRS_API_BASE_URL=http://192.168.x.x:8000/api/v1
```

Override yang sama dapat digunakan untuk web/server selain alamat lokal default.
Atur `CORS_ALLOWED_ORIGINS` di `.env` backend ke origin web yang sebenarnya,
dipisahkan koma. HTTP lokal hanya diizinkan pada build debug; build rilis wajib
menggunakan HTTPS.

## Endpoint integrasi

API versi 1 tersedia pada `/api/v1`:

- `POST /auth/register`, `POST /auth/login`, dan `POST /auth/logout`
- `GET /portal` untuk pasien yang terhubung dan data kunjungan/pendaftaran
- `GET /schedules?date=YYYY-MM-DD`
- `POST /appointments` dan `POST /appointments/{id}/cancel`
- `POST /patient-access-requests`
- `POST /patient-access-requests/{id}/decision`

API memakai bearer token acak yang disimpan dalam bentuk hash di server dan di
secure storage perangkat. Sesi berlaku 30 hari. Login pasien web yang sudah ada
dapat digunakan dari mobile; akun staf tidak dapat memakai API pasien. Password
registrasi baru di-hash dengan konfigurasi Laravel.

Permintaan akses keluarga masuk ke **Otorisasi keluarga** di dashboard staf.
Petugas harus memverifikasi identitas dan hubungan; jika pasien memiliki akun,
pasien itu juga harus menyetujui sebelum akses keluarga diberikan. Check-in tetap
dilakukan petugas di web agar kehadiran tidak dapat dipalsukan dari perangkat.

## Batasan backend yang ada

Integrasi mengikuti fitur dan skema web di arsip, bukan membuat respons demo:

- Portal web saat ini belum mempunyai modul keuangan/tabel tagihan, backend
  notifikasi, Patient Report yang dapat dibagikan, maupun API chat telekonsultasi
  untuk mobile. Bagian tersebut belum ditampilkan sebagai data nyata di mobile.
- Modul antrean web belum mengelola status `CALLED`/estimasi waktu tunggu, sehingga
  mobile menampilkan status pendaftaran yang benar-benar tersedia dan tidak
  mengarang nomor yang sedang dilayani.
- Akses pasien keluarga memerlukan migrasi baru serta verifikasi petugas/persetujuan
  pasien. Data keluarga tidak otomatis dapat dilihat hanya berdasarkan NIK atau
  hubungan keluarga.
- Backend Laravel di arsip tidak menyertakan migrasi skema inti pasien, jadwal,
  dan pendaftaran maupun dump database. Migrasi baru di [backend/database/migrations](./backend/database/migrations)
  harus dijalankan pada database web yang sudah memiliki skema inti tersebut.

Ini adalah dasar integrasi MVP, bukan klaim bahwa seluruh persyaratan produksi
PRD sudah terpenuhi. Audit akses menyeluruh, refresh/revocation policy token,
notifikasi near-real-time, billing, patient reports dengan persetujuan,
telekonsultasi mobile, pemulihan password, perubahan profil, dan audit log masih
perlu diselesaikan sebelum penggunaan klinis/produksi.

## Validasi

```powershell
flutter analyze
flutter test
```
