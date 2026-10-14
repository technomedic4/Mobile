<?php

use App\Http\Controllers\MobileApiController;
use App\Http\Middleware\AuthenticateMobileToken;
use Illuminate\Support\Facades\Route;

Route::prefix('v1')->group(function (): void {
    Route::post('/auth/register', [MobileApiController::class, 'register'])
        ->middleware('throttle:5,1');
    Route::post('/auth/login', [MobileApiController::class, 'login'])
        ->middleware('throttle:10,1');

    Route::middleware(AuthenticateMobileToken::class)->group(function (): void {
        Route::post('/auth/logout', [MobileApiController::class, 'logout']);
        Route::get('/me', [MobileApiController::class, 'me']);
        Route::get('/portal', [MobileApiController::class, 'portal']);
        Route::get('/schedules', [MobileApiController::class, 'schedules']);
        Route::post('/patient-access-requests', [MobileApiController::class, 'requestPatientAccess']);
        Route::post('/patient-access-requests/{accessRequest}/decision', [MobileApiController::class, 'decidePatientAccess']);
        Route::post('/appointments', [MobileApiController::class, 'book']);
        Route::post('/appointments/{appointment}/cancel', [MobileApiController::class, 'cancel']);
    });
});
