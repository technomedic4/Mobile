<?php

namespace App\Http\Controllers;

use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;

class MobileApiController extends Controller
{
    private const DAY_NAMES = [
        1 => 'Senin',
        2 => 'Selasa',
        3 => 'Rabu',
        4 => 'Kamis',
        5 => 'Jumat',
        6 => 'Sabtu',
        7 => 'Minggu',
    ];

    public function register(Request $request): JsonResponse
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'max:150'],
            'nik' => ['required', 'digits:16', Rule::unique('patient_profiles', 'national_id')],
            'phone' => ['required', 'string', 'max:20'],
            'birth_date' => ['required', 'date', 'before_or_equal:today'],
            'gender' => ['required', Rule::in(['L', 'P'])],
            'address' => ['required', 'string', 'max:2000'],
            'email' => ['required', 'email', 'max:255', Rule::unique('users', 'email')],
            'password' => ['required', 'string', 'min:8', 'confirmed'],
        ]);

        $roleId = DB::table('roles')->where('role_name', 'Pasien')->value('id');

        if ($roleId === null) {
            return response()->json(['message' => 'Peran pasien belum dikonfigurasi di server.'], 503);
        }

        [$user, $profile, $plainTextToken] = DB::transaction(function () use ($data, $roleId): array {
            $userId = DB::table('users')->insertGetId([
                'role_id' => $roleId,
                'email' => Str::lower($data['email']),
                'phone_number' => $data['phone'],
                'password_hash' => Hash::make($data['password']),
                'is_active' => true,
                'created_at' => now(),
            ]);

            $patientId = DB::table('patient_profiles')->insertGetId([
                'user_id' => $userId,
                'medical_record_number' => null,
                'national_id' => $data['nik'],
                'full_name' => $data['name'],
                'phone_number' => $data['phone'],
                'birth_date' => $data['birth_date'],
                'gender' => $data['gender'],
                'address' => $data['address'],
            ]);

            DB::table('patient_profiles')
                ->where('id', $patientId)
                ->update(['medical_record_number' => 'RM-'.str_pad((string) $patientId, 8, '0', STR_PAD_LEFT)]);

            $plainTextToken = $this->issueToken($userId);

            return [
                User::query()->findOrFail($userId),
                DB::table('patient_profiles')->where('id', $patientId)->first(),
                $plainTextToken,
            ];
        });

        return response()->json($this->sessionPayload($user, $profile, $plainTextToken), 201);
    }

    public function login(Request $request): JsonResponse
    {
        $data = $request->validate([
            'email' => ['required', 'email'],
            'password' => ['required', 'string'],
        ]);

        $user = User::query()->where('email', Str::lower($data['email']))->first();
        $profile = $user === null
            ? null
            : DB::table('patient_profiles')->where('user_id', $user->id)->first();
        $storedPassword = $user?->getAuthPassword();
        $passwordMatches = $storedPassword !== null
            && (password_get_info($storedPassword)['algoName'] === 'bcrypt'
                ? Hash::check($data['password'], $storedPassword)
                : hash_equals($storedPassword, $data['password']));
        $roleIsPatient = $user !== null
            && DB::table('roles')
                ->where('id', $user->role_id)
                ->where('role_name', 'Pasien')
                ->exists();

        if (! $passwordMatches || ! $user->is_active || ! $roleIsPatient || $profile === null) {
            throw ValidationException::withMessages([
                'email' => 'Email atau password salah, atau akun tidak memiliki akses portal pasien.',
            ]);
        }

        if (password_get_info($storedPassword)['algoName'] !== 'bcrypt') {
            DB::table('users')->where('id', $user->id)->update([
                'password_hash' => Hash::make($data['password']),
            ]);
        }

        return response()->json($this->sessionPayload($user, $profile, $this->issueToken($user->id)));
    }

    public function logout(Request $request): JsonResponse
    {
        DB::table('mobile_access_tokens')
            ->where('token_hash', hash('sha256', (string) $request->bearerToken()))
            ->delete();

        return response()->json(['message' => 'Anda telah keluar.']);
    }

    public function me(Request $request): JsonResponse
    {
        return response()->json([
            'user' => $this->userPayload($request->user()),
            'patient' => $this->ownPatient($request),
        ]);
    }

    public function portal(Request $request): JsonResponse
    {
        $patientIds = $this->authorizedPatientIds($request);

        $appointments = DB::table('appointments')
            ->join('patient_profiles', 'patient_profiles.id', '=', 'appointments.patient_id')
            ->join('doctor_schedules', 'doctor_schedules.id', '=', 'appointments.doctor_schedule_id')
            ->join('doctors', 'doctors.id', '=', 'doctor_schedules.doctor_id')
            ->join('departments', 'departments.id', '=', 'doctors.department_id')
            ->whereIn('appointments.patient_id', $patientIds)
            ->select([
                'appointments.id',
                'appointments.patient_id',
                'patient_profiles.full_name as patient_name',
                'departments.name as department_name',
                'doctors.full_name as doctor_name',
                'appointments.appointment_date',
                'doctor_schedules.start_time',
                'appointments.initial_complaint',
                'appointments.queue_number',
                'appointments.status',
                'appointments.consultation_type',
            ])
            ->orderByDesc('appointments.appointment_date')
            ->orderByDesc('appointments.id')
            ->get()
            ->map(fn (object $appointment): array => $this->appointmentPayload($appointment));

        return response()->json([
            'user' => $this->userPayload($request->user()),
            'patients' => $this->patientsForAccount($request),
            'appointments' => $appointments,
            'visits' => $this->visitsForPatients($patientIds),
            'reports' => [],
            'bills' => [],
            'notifications' => [],
            'currently_serving' => [],
            'pending_access_requests' => DB::table('patient_access_requests')
                ->join('patient_profiles', 'patient_profiles.id', '=', 'patient_access_requests.patient_id')
                ->where('patient_profiles.user_id', $request->user()->id)
                ->where('patient_access_requests.status', 'AwaitingPatientConsent')
                ->select([
                    'patient_access_requests.id',
                    'patient_access_requests.relationship',
                    'patient_profiles.full_name as patient_name',
                ])
                ->get(),
        ]);
    }

    public function requestPatientAccess(Request $request): JsonResponse
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'max:150'],
            'nik' => ['required', 'digits:16'],
            'phone' => ['required', 'string', 'max:20'],
            'birth_date' => ['nullable', 'date', 'before_or_equal:today'],
            'gender' => ['nullable', Rule::in(['L', 'P'])],
            'address' => ['nullable', 'string', 'max:2000'],
            'relationship' => ['required', Rule::in(['Ibu', 'Ayah', 'Anak', 'Suami', 'Istri', 'Saudara', 'Wali', 'Lainnya'])],
        ]);

        $existingPatient = DB::table('patient_profiles')
            ->where('national_id', $data['nik'])
            ->first();

        if ($existingPatient?->user_id === $request->user()->id) {
            throw ValidationException::withMessages([
                'nik' => 'Pasien ini sudah menjadi profil utama akun Anda.',
            ]);
        }

        $alreadyAuthorized = $existingPatient !== null
            && DB::table('authorized_patient_accounts')
                ->where('patient_id', $existingPatient->id)
                ->where('account_user_id', $request->user()->id)
                ->exists();

        if ($alreadyAuthorized) {
            throw ValidationException::withMessages([
                'nik' => 'Pasien ini sudah terhubung ke akun Anda.',
            ]);
        }

        $pendingRequest = DB::table('patient_access_requests')
            ->where('requester_user_id', $request->user()->id)
            ->where('national_id', $data['nik'])
            ->whereIn('status', ['Pending', 'AwaitingPatientConsent'])
            ->exists();

        if ($pendingRequest) {
            throw ValidationException::withMessages([
                'nik' => 'Permintaan untuk pasien ini sedang menunggu verifikasi rumah sakit.',
            ]);
        }

        DB::table('patient_access_requests')->insert([
            'requester_user_id' => $request->user()->id,
            'patient_id' => $existingPatient?->id,
            'national_id' => $data['nik'],
            'patient_name' => $data['name'],
            'phone_number' => $data['phone'],
            'birth_date' => $data['birth_date'] ?? null,
            'gender' => $data['gender'] ?? null,
            'address' => ($data['address'] ?? null) ?: null,
            'relationship' => $data['relationship'],
            'status' => 'Pending',
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        return response()->json([
            'message' => 'Permintaan telah dikirim dan akan tersedia setelah diverifikasi rumah sakit serta disetujui pasien.',
        ], 202);
    }

    public function decidePatientAccess(Request $request, int $accessRequest): JsonResponse
    {
        $data = $request->validate([
            'decision' => ['required', Rule::in(['approve', 'reject'])],
        ]);

        $access = DB::table('patient_access_requests')
            ->join('patient_profiles', 'patient_profiles.id', '=', 'patient_access_requests.patient_id')
            ->where('patient_access_requests.id', $accessRequest)
            ->where('patient_profiles.user_id', $request->user()->id)
            ->where('patient_access_requests.status', 'AwaitingPatientConsent')
            ->select('patient_access_requests.id', 'patient_access_requests.requester_user_id', 'patient_profiles.id as patient_id', 'patient_access_requests.relationship')
            ->first();

        abort_if($access === null, 404);

        DB::transaction(function () use ($access, $data, $request): void {
            if ($data['decision'] === 'approve') {
                $now = now();
                DB::table('authorized_patient_accounts')->insertOrIgnore([
                    'patient_id' => $access->patient_id,
                    'account_user_id' => $access->requester_user_id,
                    'relationship' => $access->relationship,
                    'approved_by_user_id' => $request->user()->id,
                    'approved_at' => $now,
                    'created_at' => $now,
                    'updated_at' => $now,
                ]);
            }

            DB::table('patient_access_requests')
                ->where('id', $access->id)
                ->update([
                    'status' => $data['decision'] === 'approve' ? 'Approved' : 'Rejected',
                    'reviewed_by_user_id' => $request->user()->id,
                    'reviewed_at' => now(),
                    'updated_at' => now(),
                ]);
        });

        return response()->json([
            'message' => $data['decision'] === 'approve'
                ? 'Akses keluarga telah disetujui.'
                : 'Permintaan akses keluarga ditolak.',
        ]);
    }

    public function schedules(Request $request): JsonResponse
    {
        $data = $request->validate([
            'date' => ['required', 'date', 'after_or_equal:today'],
        ]);
        $date = Carbon::parse($data['date']);
        $dayName = self::DAY_NAMES[$date->dayOfWeekIso];

        $schedules = DB::table('doctor_schedules')
            ->join('doctors', 'doctors.id', '=', 'doctor_schedules.doctor_id')
            ->join('departments', 'departments.id', '=', 'doctors.department_id')
            ->where('doctor_schedules.day_of_week', $dayName)
            ->select([
                'doctor_schedules.id',
                'doctor_schedules.start_time',
                'doctor_schedules.end_time',
                'doctor_schedules.quota_limit',
                'doctors.full_name as doctor_name',
                'departments.name as department_name',
            ])
            ->orderBy('departments.name')
            ->orderBy('doctors.full_name')
            ->orderBy('doctor_schedules.start_time')
            ->get()
            ->map(function (object $schedule) use ($date): array {
                $booked = DB::table('appointments')
                    ->where('doctor_schedule_id', $schedule->id)
                    ->whereDate('appointment_date', $date->toDateString())
                    ->where('status', '!=', 'Cancelled')
                    ->count();

                return [
                    'id' => (string) $schedule->id,
                    'department' => $schedule->department_name,
                    'doctor' => $schedule->doctor_name,
                    'start_time' => substr($schedule->start_time, 0, 5),
                    'end_time' => substr($schedule->end_time, 0, 5),
                    'remaining_quota' => max(0, (int) $schedule->quota_limit - $booked),
                ];
            })
            ->filter(static fn (array $schedule): bool => $schedule['remaining_quota'] > 0)
            ->values();

        return response()->json(['data' => $schedules]);
    }

    public function book(Request $request): JsonResponse
    {
        $data = $request->validate([
            'patient_id' => ['required', 'integer'],
            'doctor_schedule_id' => ['required', 'integer'],
            'appointment_date' => ['required', 'date', 'after_or_equal:today'],
            'initial_complaint' => ['nullable', 'string', 'max:2000'],
            'consultation_type' => ['nullable', Rule::in(['In-Person', 'Teleconsultation'])],
        ]);

        $appointmentId = DB::transaction(function () use ($request, $data): int {
            $patient = DB::table('patient_profiles')
                ->where('id', $data['patient_id'])
                ->where(function ($query) use ($request): void {
                    $query->where('user_id', $request->user()->id)
                        ->orWhereExists(function ($query) use ($request): void {
                            $query->selectRaw('1')
                                ->from('authorized_patient_accounts')
                                ->whereColumn('authorized_patient_accounts.patient_id', 'patient_profiles.id')
                                ->where('authorized_patient_accounts.account_user_id', $request->user()->id);
                        });
                })
                ->first();

            if ($patient === null) {
                abort(404, 'Pasien tidak terhubung dengan akun ini.');
            }

            $schedule = DB::table('doctor_schedules')
                ->where('id', $data['doctor_schedule_id'])
                ->lockForUpdate()
                ->first();
            $dayName = self::DAY_NAMES[Carbon::parse($data['appointment_date'])->dayOfWeekIso];

            if ($schedule === null || $schedule->day_of_week !== $dayName || (int) $schedule->quota_limit < 1) {
                throw ValidationException::withMessages([
                    'doctor_schedule_id' => 'Jadwal dokter tidak tersedia pada tanggal yang dipilih.',
                ]);
            }

            $usedNumbers = DB::table('appointments')
                ->where('doctor_schedule_id', $schedule->id)
                ->whereDate('appointment_date', $data['appointment_date'])
                ->where('status', '!=', 'Cancelled')
                ->pluck('queue_number')
                ->map(static fn ($number): int => (int) $number)
                ->all();
            $available = array_values(array_diff(range(1, (int) $schedule->quota_limit), $usedNumbers));
            $queueNumber = $available[0] ?? null;

            if ($queueNumber === null) {
                throw ValidationException::withMessages([
                    'doctor_schedule_id' => 'Kuota jadwal dokter untuk tanggal tersebut sudah penuh.',
                ]);
            }

            do {
                $bookingCode = 'REG-'.str_replace('-', '', $data['appointment_date']).'-'.Str::upper(Str::random(6));
            } while (DB::table('appointments')->where('booking_code', $bookingCode)->exists());

            return DB::table('appointments')->insertGetId([
                'booking_code' => $bookingCode,
                'patient_id' => $patient->id,
                'doctor_schedule_id' => $schedule->id,
                'appointment_date' => $data['appointment_date'],
                'queue_number' => $queueNumber,
                'initial_complaint' => ($data['initial_complaint'] ?? null) ?: null,
                'consultation_type' => $data['consultation_type'] ?? 'In-Person',
                'status' => 'Pending',
                'created_at' => now(),
            ]);
        });

        $appointment = DB::table('appointments')
            ->join('patient_profiles', 'patient_profiles.id', '=', 'appointments.patient_id')
            ->join('doctor_schedules', 'doctor_schedules.id', '=', 'appointments.doctor_schedule_id')
            ->join('doctors', 'doctors.id', '=', 'doctor_schedules.doctor_id')
            ->join('departments', 'departments.id', '=', 'doctors.department_id')
            ->where('appointments.id', $appointmentId)
            ->select([
                'appointments.id',
                'appointments.patient_id',
                'patient_profiles.full_name as patient_name',
                'departments.name as department_name',
                'doctors.full_name as doctor_name',
                'appointments.appointment_date',
                'doctor_schedules.start_time',
                'appointments.initial_complaint',
                'appointments.queue_number',
                'appointments.status',
                'appointments.consultation_type',
            ])
            ->first();

        return response()->json($this->appointmentPayload($appointment), 201);
    }

    public function cancel(Request $request, int $appointment): JsonResponse
    {
        $updated = DB::table('appointments')
            ->where('id', $appointment)
            ->whereIn('patient_id', $this->authorizedPatientIds($request))
            ->whereIn('status', ['Pending', 'Confirmed'])
            ->update(['status' => 'Cancelled']);

        if ($updated === 0) {
            abort_unless(
                DB::table('appointments')
                    ->where('id', $appointment)
                    ->whereIn('patient_id', $this->authorizedPatientIds($request))
                    ->exists(),
                404,
            );

            throw ValidationException::withMessages([
                'appointment' => 'Pendaftaran yang sudah check-in atau selesai tidak dapat dibatalkan.',
            ]);
        }

        return response()->json(['message' => 'Pendaftaran berhasil dibatalkan.']);
    }

    /**
     * @return array{user: array<string, mixed>, patient: array<string, mixed>, token: string, token_type: string, expires_at: string}
     */
    private function sessionPayload(User $user, object $profile, string $plainTextToken): array
    {
        $token = DB::table('mobile_access_tokens')
            ->where('token_hash', hash('sha256', $plainTextToken))
            ->first();

        return [
            'user' => $this->userPayload($user),
            'patient' => $this->patientPayload($profile),
            'token' => $plainTextToken,
            'token_type' => 'Bearer',
            'expires_at' => Carbon::parse($token->expires_at)->toIso8601String(),
        ];
    }

    private function issueToken(int $userId): string
    {
        $plainTextToken = bin2hex(random_bytes(32));
        $now = now();

        DB::table('mobile_access_tokens')->insert([
            'user_id' => $userId,
            'token_hash' => hash('sha256', $plainTextToken),
            'expires_at' => $now->copy()->addDays(30),
            'created_at' => $now,
            'updated_at' => $now,
        ]);

        return $plainTextToken;
    }

    private function userPayload(User $user): array
    {
        return [
            'id' => (string) $user->id,
            'email' => $user->email,
        ];
    }

    private function patientPayload(object $patient, string $relationship = 'Diri sendiri'): array
    {
        return [
            'id' => (string) $patient->id,
            'medical_record_number' => (string) ($patient->medical_record_number ?? ''),
            'nik' => (string) ($patient->national_id ?? ''),
            'name' => $patient->full_name,
            'birth_date' => (string) ($patient->birth_date ?? ''),
            'gender' => match ($patient->gender ?? null) {
                'L' => 'Laki-laki',
                'P' => 'Perempuan',
                default => 'Belum diisi',
            },
            'address' => (string) ($patient->address ?? ''),
            'phone' => (string) ($patient->phone_number ?? ''),
            'relationship' => $relationship,
            'is_authorized' => true,
            'owner_account' => '',
        ];
    }

    private function ownPatient(Request $request): ?array
    {
        $patient = DB::table('patient_profiles')
            ->where('user_id', $request->user()->id)
            ->first();

        return $patient === null ? null : $this->patientPayload($patient);
    }

    private function patientsForAccount(Request $request): array
    {
        return DB::table('patient_profiles')
            ->whereIn('id', $this->authorizedPatientIds($request))
            ->select(['id', 'user_id', 'medical_record_number', 'national_id', 'full_name', 'birth_date', 'gender', 'address', 'phone_number'])
            ->orderBy('id')
            ->get()
            ->map(fn (object $patient): array => $this->patientPayload(
                $patient,
                $patient->user_id === $request->user()->id ? 'Diri sendiri' : $this->relationshipFor($request, $patient->id),
            ))
            ->all();
    }

    private function authorizedPatientIds(Request $request): \Illuminate\Support\Collection
    {
        return DB::table('patient_profiles')
            ->where('user_id', $request->user()->id)
            ->orWhereExists(function ($query) use ($request): void {
                $query->selectRaw('1')
                    ->from('authorized_patient_accounts')
                    ->whereColumn('authorized_patient_accounts.patient_id', 'patient_profiles.id')
                    ->where('authorized_patient_accounts.account_user_id', $request->user()->id);
            })
            ->pluck('id');
    }

    private function relationshipFor(Request $request, int $patientId): string
    {
        return (string) DB::table('authorized_patient_accounts')
            ->where('patient_id', $patientId)
            ->where('account_user_id', $request->user()->id)
            ->value('relationship');
    }

    private function appointmentPayload(object $appointment): array
    {
        return [
            'id' => (string) $appointment->id,
            'patient_id' => (string) $appointment->patient_id,
            'patient_name' => $appointment->patient_name,
            'poly' => $appointment->department_name,
            'doctor' => $appointment->doctor_name,
            'date' => (string) $appointment->appointment_date,
            'schedule' => substr($appointment->start_time, 0, 5),
            'complaint' => (string) ($appointment->initial_complaint ?? ''),
            'queue_number' => $this->queuePrefix($appointment->department_name)
                .'-'.str_pad((string) $appointment->queue_number, 3, '0', STR_PAD_LEFT),
            'status' => Str::upper(str_replace('-', '_', $appointment->status)),
            'registration_status' => Str::upper(str_replace('-', '_', $appointment->status)),
            'consultation_type' => $appointment->consultation_type,
        ];
    }

    private function queuePrefix(string $department): string
    {
        return match ($department) {
            'Poli Anak' => 'B',
            'Poli Umum', 'Penyakit Dalam' => 'A',
            default => Str::upper(Str::substr($department, 0, 1)),
        };
    }

    private function visitsForPatients(\Illuminate\Support\Collection $patientIds): array
    {
        if ($patientIds->isEmpty()) {
            return [];
        }

        return DB::table('doctor_consultations')
            ->join('appointments', 'appointments.id', '=', 'doctor_consultations.appointment_id')
            ->join('doctors', 'doctors.id', '=', 'doctor_consultations.doctor_id')
            ->join('departments', 'departments.id', '=', 'doctors.department_id')
            ->whereIn('doctor_consultations.patient_id', $patientIds)
            ->where('appointments.status', 'Completed')
            ->select([
                'doctor_consultations.patient_id',
                'appointments.appointment_date',
                'departments.name as department_name',
                'doctors.full_name as doctor_name',
                'appointments.initial_complaint',
                'doctor_consultations.diagnosis',
                'doctor_consultations.treatment_plan',
            ])
            ->orderByDesc('appointments.appointment_date')
            ->get()
            ->map(static fn (object $visit): array => [
                'id' => (string) $visit->patient_id.'-'.$visit->appointment_date,
                'patient_id' => (string) $visit->patient_id,
                'date' => (string) $visit->appointment_date,
                'poly' => $visit->department_name,
                'doctor' => $visit->doctor_name,
                'complaint' => (string) ($visit->initial_complaint ?? ''),
                'diagnosis' => $visit->diagnosis,
                'treatment' => $visit->treatment_plan,
            ])
            ->all();
    }
}
