<p align="center"><a href="https://laravel.com" target="_blank"><img src="https://raw.githubusercontent.com/laravel/art/master/logo-lockup/5%20SVG/2%20CMYK/1%20Full%20Color/laravel-logolockup-cmyk-red.svg" width="400" alt="Laravel Logo"></a></p>

<p align="center">
<a href="https://github.com/laravel/framework/actions"><img src="https://github.com/laravel/framework/workflows/tests/badge.svg" alt="Build Status"></a>
<a href="https://packagist.org/packages/laravel/framework"><img src="https://img.shields.io/packagist/dt/laravel/framework" alt="Total Downloads"></a>
<a href="https://packagist.org/packages/laravel/framework"><img src="https://img.shields.io/packagist/v/laravel/framework" alt="Latest Stable Version"></a>
<a href="https://packagist.org/packages/laravel/framework"><img src="https://img.shields.io/packagist/l/laravel/framework" alt="License"></a>
</p>

## Koneksi MySQL untuk API mobile dan portal web

Portal web dan aplikasi mobile memakai backend Laravel ini, sehingga keduanya
mengakses database MySQL yang sama melalui backend. Jangan menghubungkan aplikasi
mobile langsung ke server MySQL.

1. Buat `backend/.env` dari `backend/.env.example`.
2. Atur `DB_HOST`, `DB_PORT`, `DB_DATABASE`, `DB_USERNAME`, dan `DB_PASSWORD`
   sesuai server MySQL Anda. Jangan commit file `.env` atau membagikan kata sandi
   database. Setelah mengganti versi Laragon, pastikan `DB_PORT` menunjuk ke
   MySQL Laragon yang aktif dan `DB_DATABASE` sama persis dengan nama database
   yang dipulihkan.
3. Pastikan akun MySQL memiliki hak akses ke database tersebut, lalu jalankan
   dari folder `backend`:

   ```powershell
   php artisan config:clear
   php artisan migrate:status
   ```

   Tinjau status dan skema database terlebih dahulu. Migrasi proyek harus
   diterapkan hanya pada database yang benar; jangan menjalankan migrasi secara
   membabi buta pada database produksi.
4. Backend ini memerlukan PHP 8.3 atau lebih baru (`composer.json`). Setelah
   mengganti versi Laragon, pastikan PHP CLI yang dipakai `php artisan` juga
   versi yang kompatibel; periksa dengan `php -v`.
5. Jalankan API Laravel dan konfigurasi URL API pada aplikasi Flutter sesuai
   petunjuk di README proyek utama.

Migrasi inti untuk tabel pasien, jadwal, dan pendaftaran harus sudah tersedia
dari proyek web. Migrasi mobile menambahkan tabel token dan otorisasi pasien;
migrasi tersebut mengasumsikan tabel inti web yang direferensikannya sudah ada.

## About Laravel

Laravel is a web application framework with expressive, elegant syntax. We believe development must be an enjoyable and creative experience to be truly fulfilling. Laravel takes the pain out of development by easing common tasks used in many web projects, such as:

- [Simple, fast routing engine](https://laravel.com/docs/routing).
- [Powerful dependency injection container](https://laravel.com/docs/container).
- Multiple back-ends for [session](https://laravel.com/docs/session) and [cache](https://laravel.com/docs/cache) storage.
- Expressive, intuitive [database ORM](https://laravel.com/docs/eloquent).
- Database agnostic [schema migrations](https://laravel.com/docs/migrations).
- [Robust background job processing](https://laravel.com/docs/queues).
- [Real-time event broadcasting](https://laravel.com/docs/broadcasting).

Laravel is accessible, powerful, and provides tools required for large, robust applications.

## Learning Laravel

Laravel has the most extensive and thorough [documentation](https://laravel.com/docs) and video tutorial library of all modern web application frameworks, making it a breeze to get started with the framework.

In addition, [Laracasts](https://laracasts.com) contains thousands of video tutorials on a range of topics including Laravel, modern PHP, unit testing, and JavaScript. Boost your skills by digging into our comprehensive video library.

You can also watch bite-sized lessons with real-world projects on [Laravel Learn](https://laravel.com/learn), where you will be guided through building a Laravel application from scratch while learning PHP fundamentals.

## Agentic Development

Laravel's predictable structure and conventions make it ideal for AI coding agents like Claude Code, Cursor, and GitHub Copilot. Install [Laravel Boost](https://laravel.com/docs/ai) to supercharge your AI workflow:

```bash
composer require laravel/boost --dev

php artisan boost:install
```

Boost provides your agent 15+ tools and skills that help agents build Laravel applications while following best practices.

## Contributing

Thank you for considering contributing to the Laravel framework! The contribution guide can be found in the [Laravel documentation](https://laravel.com/docs/contributions).

## Code of Conduct

In order to ensure that the Laravel community is welcoming to all, please review and abide by the [Code of Conduct](https://laravel.com/docs/contributions#code-of-conduct).

## Security Vulnerabilities

If you discover a security vulnerability within Laravel, please send an e-mail to Taylor Otwell via [taylor@laravel.com](mailto:taylor@laravel.com). All security vulnerabilities will be promptly addressed.

## License

The Laravel framework is open-sourced software licensed under the [MIT license](https://opensource.org/licenses/MIT).
