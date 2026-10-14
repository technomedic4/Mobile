<?php

namespace App\Http\Middleware;

use App\Models\User;
use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Symfony\Component\HttpFoundation\Response;

class AuthenticateMobileToken
{
    public function handle(Request $request, Closure $next): Response
    {
        $plainTextToken = $request->bearerToken();

        if ($plainTextToken === null || strlen($plainTextToken) !== 64) {
            return response()->json(['message' => 'Sesi tidak valid. Silakan masuk kembali.'], 401);
        }

        $token = DB::table('mobile_access_tokens')
            ->where('token_hash', hash('sha256', $plainTextToken))
            ->first();

        if ($token === null || \Illuminate\Support\Carbon::parse($token->expires_at)->isPast()) {
            if ($token !== null) {
                DB::table('mobile_access_tokens')->where('id', $token->id)->delete();
            }

            return response()->json(['message' => 'Sesi telah berakhir. Silakan masuk kembali.'], 401);
        }

        $user = User::query()->find($token->user_id);
        $isPatient = $user !== null
            && $user->is_active
            && DB::table('roles')
                ->where('id', $user->role_id)
                ->where('role_name', 'Pasien')
                ->exists();

        if (! $isPatient) {
            DB::table('mobile_access_tokens')->where('id', $token->id)->delete();

            return response()->json(['message' => 'Akun tidak memiliki akses aplikasi pasien.'], 403);
        }

        DB::table('mobile_access_tokens')
            ->where('id', $token->id)
            ->update(['last_used_at' => now()]);

        $request->setUserResolver(static fn () => $user);

        return $next($request);
    }
}
