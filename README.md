# SIMRS Sehat — aplikasi mobile pasien

Aplikasi Flutter ini memakai API Laravel milik portal web dan berbagi database
rumah sakit yang sama. Aplikasi mobile tidak terhubung langsung ke MySQL.

## Menjalankan aplikasi

1. Pastikan backend web telah dikonfigurasi ke database yang benar dan server
   Laravel berjalan pada port yang dapat dijangkau perangkat.
2. Dari root repositori mobile, jalankan:

   ```powershell
   flutter pub get
   flutter run
   ```

   Android Emulator menggunakan `http://10.0.2.2:8000/api/v1` secara otomatis
   pada mode debug. Untuk perangkat fisik, gunakan alamat server yang dapat
   dijangkau perangkat dan atur `SIMRS_API_BASE_URL`; build rilis harus memakai
   HTTPS.

   ```powershell
   flutter run --dart-define=SIMRS_API_BASE_URL=https://server-anda.example/api/v1
   ```

## Fitur dan API

- Login pasien dan pemuatan profil, pasien yang terhubung, janji, serta riwayat
  pemeriksaan melalui API `/api/v1`.
- Pendaftaran kunjungan langsung atau telekonsultasi.
- Chat pasien dan dokter untuk janji telekonsultasi yang masih aktif.
- Tagihan, rincian dan saldo, serta pengajuan pembayaran transfer/QRIS dengan
  bukti yang ditinjau petugas. Pengajuan tidak langsung melunasi tagihan.

API tagihan dan chat berada di backend web. Jalankan migrasi backend web sebelum
menggunakan pengajuan pembayaran agar tabel `mobile_payment_submissions`
tersedia. Instruksi bank dan QRIS dikonfigurasi melalui variabel
`BILLING_BANK_NAME`, `BILLING_BANK_ACCOUNT`, `BILLING_BANK_ACCOUNT_NAME`,
`BILLING_QRIS_MERCHANT_NAME`, dan `BILLING_QRIS_IMAGE_URL` pada `.env` backend.

## Validasi

```powershell
flutter analyze
flutter test
```
