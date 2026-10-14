<?php

namespace App\Http\Controllers\Staff;

use App\Http\Controllers\Controller;
use Illuminate\Contracts\View\View;
use Illuminate\Http\RedirectResponse;
use Illuminate\Support\Facades\DB;

class PatientAccessController extends Controller
{
    public function index(): View
    {
        $requests = DB::table('patient_access_requests')
            ->join('users', 'users.id', '=', 'patient_access_requests.requester_user_id')
            ->leftJoin('patient_profiles', 'patient_profiles.id', '=', 'patient_access_requests.patient_id')
            ->where('patient_access_requests.status', 'Pending')
            ->select([
                'patient_access_requests.*',
                'users.email as requester_email',
                'patient_profiles.full_name as existing_patient_name',
            ])
            ->orderBy('patient_access_requests.created_at')
            ->get();

        return view('staff.patient-access-requests.index', compact('requests'));
    }

    public function approve(int $accessRequest): RedirectResponse
    {
        DB::transaction(function () use ($accessRequest): void {
            $request = DB::table('patient_access_requests')
                ->where('id', $accessRequest)
                ->where('status', 'Pending')
                ->lockForUpdate()
                ->first();

            abort_if($request === null, 404);

            $patient = $request->patient_id === null
                ? DB::table('patient_profiles')->where('national_id', $request->national_id)->first()
                : DB::table('patient_profiles')->where('id', $request->patient_id)->first();

            if ($patient === null) {
                $patientId = DB::table('patient_profiles')->insertGetId([
                    'user_id' => null,
                    'medical_record_number' => null,
                    'national_id' => $request->national_id,
                    'full_name' => $request->patient_name,
                    'phone_number' => $request->phone_number,
                    'gender' => $request->gender,
                    'birth_date' => $request->birth_date,
                    'address' => $request->address,
                ]);
                DB::table('patient_profiles')
                    ->where('id', $patientId)
                    ->update(['medical_record_number' => 'RM-'.str_pad((string) $patientId, 8, '0', STR_PAD_LEFT)]);
                $awaitingConsent = false;
            } else {
                $patientId = (int) $patient->id;
                $awaitingConsent = $patient->user_id !== null;
            }

            $reviewedBy = auth()->id();
            $now = now();

            if (! $awaitingConsent) {
                DB::table('authorized_patient_accounts')->insertOrIgnore([
                    'patient_id' => $patientId,
                    'account_user_id' => $request->requester_user_id,
                    'relationship' => $request->relationship,
                    'approved_by_user_id' => $reviewedBy,
                    'approved_at' => $now,
                    'created_at' => $now,
                    'updated_at' => $now,
                ]);
            }

            DB::table('patient_access_requests')
                ->where('id', $request->id)
                ->update([
                    'patient_id' => $patientId,
                    'status' => $awaitingConsent ? 'AwaitingPatientConsent' : 'Approved',
                    'reviewed_by_user_id' => $reviewedBy,
                    'reviewed_at' => $now,
                    'updated_at' => $now,
                ]);
        });

        return back()->with('success', 'Identitas dan permintaan telah diverifikasi. Pasien yang memiliki akun harus memberikan persetujuan sebelum akses dibuka.');
    }

    public function reject(int $accessRequest): RedirectResponse
    {
        $updated = DB::table('patient_access_requests')
            ->where('id', $accessRequest)
            ->where('status', 'Pending')
            ->update([
                'status' => 'Rejected',
                'reviewed_by_user_id' => auth()->id(),
                'reviewed_at' => now(),
                'updated_at' => now(),
            ]);

        abort_if($updated === 0, 404);

        return back()->with('success', 'Permintaan akses keluarga ditolak.');
    }
}
