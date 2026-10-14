<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Otorisasi keluarga | TechnoMedic</title>
    <link rel="stylesheet" href="{{ asset('CSS/staff.css') }}">
</head>
<body class="staff-body">
    <main class="staff-main">
        <div class="staff-content">
            <section class="staff-page-heading">
                <div>
                    <p class="staff-eyebrow">PERLINDUNGAN DATA PASIEN</p>
                    <h1>Permintaan akses keluarga</h1>
                    <p>Periksa identitas dan otorisasi sebelum membuka informasi pasien kepada akun keluarga.</p>
                </div>
                <a class="staff-secondary-button staff-button-link" href="{{ route('staff.dashboard') }}">Kembali ke dashboard</a>
            </section>

            @if (session('success'))
                <section class="staff-alert staff-alert-info" role="status">{{ session('success') }}</section>
            @endif

            @forelse ($requests as $accessRequest)
                <article class="staff-stat-card" style="margin-bottom: 1rem">
                    <h2>{{ $accessRequest->patient_name }}</h2>
                    <p>NIK: {{ $accessRequest->national_id }} · {{ $accessRequest->relationship }}</p>
                    <p>Nomor HP: {{ $accessRequest->phone_number }} · Tanggal lahir: {{ $accessRequest->birth_date ?: 'Belum diisi' }}</p>
                    <p>Pemohon: {{ $accessRequest->requester_email }} · Pasien terdaftar: {{ $accessRequest->existing_patient_name ?: 'Belum ada' }}</p>
                    <p>Alamat: {{ $accessRequest->address ?: 'Belum diisi' }}</p>
                    <form method="post" action="{{ route('staff.patient-access-requests.approve', $accessRequest->id) }}" style="display:inline">
                        @csrf
                        <button class="staff-action-button" type="submit">Verifikasi identitas & hubungan</button>
                    </form>
                    <form method="post" action="{{ route('staff.patient-access-requests.reject', $accessRequest->id) }}" style="display:inline">
                        @csrf
                        <button class="staff-secondary-button" type="submit">Tolak</button>
                    </form>
                </article>
            @empty
                <p>Tidak ada permintaan otorisasi yang menunggu.</p>
            @endforelse
        </div>
    </main>
</body>
</html>
