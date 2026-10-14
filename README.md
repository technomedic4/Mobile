# SIMRS Sehat — aplikasi pasien

Aplikasi Flutter ini terhubung ke backend Laravel yang juga digunakan portal web
di [backend](./backend). Kedua aplikasi membaca dan menulis data pasien serta
pendaftaran pada database rumah sakit yang sama; aplikasi mobile tidak lagi
menggunakan akun demo atau data contoh lokal.

## Menjalankan aplikasi mobile

1. Siapkan backend Laravel dan database yang dipakai portal web. Pastikan migrasi
   portal web yang sudah ada telah diterapkan sebelum menerapkan migrasi mobile.
2. Konfigurasikan URL HTTPS publik API, atau untuk emulator Android lokal gunakan
   `http://10.0.2.2:8000/api/v1`.
3. Jalankan:

   ```powershell
   flutter pub get
   flutter run --dart-define=SIMRS_API_BASE_URL=https://alamat-server/api/v1
   ```

   Untuk emulator Android dengan server lokal:

   ```powershell
   flutter run --dart-define=SIMRS_API_BASE_URL=http://10.0.2.2:8000/api/v1
   ```

   Jangan gunakan HTTP cleartext untuk build rilis atau jaringan publik. Android
   hanya mengaktifkan cleartext di manifest varian debug; rilis memerlukan HTTPS.

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

## Validasi

```powershell
flutter analyze
flutter test
```
