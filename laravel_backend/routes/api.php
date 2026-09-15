<?php

use App\Http\Controllers\Api\Admin\AdminFilterController;
use App\Http\Controllers\Api\Admin\AdminResultController;
use App\Http\Controllers\Api\Admin\AdminSessionController;
use App\Http\Controllers\Api\Admin\DeviceController;
use App\Http\Controllers\Api\Admin\EventController;
use App\Http\Controllers\Api\Admin\PrinterController;
use App\Http\Controllers\Api\Admin\ReportController;
use App\Http\Controllers\Api\Admin\ScreenConfigController;
use App\Http\Controllers\Api\Admin\TransactionController;
use App\Http\Controllers\Api\Admin\UserController;
use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\DeviceProvisioningController;
use App\Http\Controllers\Api\ErrorLogController;
use App\Http\Controllers\Api\FilterController;
use App\Http\Controllers\Api\FrameController;
use App\Http\Controllers\Api\PaymentController;
use App\Http\Controllers\Api\ResultController;
use App\Http\Controllers\Api\ScreenContentController;
use App\Http\Controllers\Api\SessionController;
use App\Http\Controllers\Api\TimerController;
use App\Http\Controllers\Api\WebhookController;
use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| Photobooth API Routes
|--------------------------------------------------------------------------
*/

// ── Kiosk Device Provisioning & Telemetry ─────────────────────────────────────
Route::post('/devices/activate', [DeviceProvisioningController::class, 'activate']);
Route::get('/devices/{device_key}/config', [DeviceProvisioningController::class, 'config']);
Route::post('/devices/heartbeat', [DeviceProvisioningController::class, 'heartbeat'])->middleware('throttle:30,1');

// ── Customer & Client Telemetry ───────────────────────────────────────────────
Route::get('/events/{event}/screen-content', [ScreenContentController::class, 'show']);
Route::get('/events/{event}/frames', [FrameController::class, 'index']);
Route::get('/events/{event}/filters', [FilterController::class, 'index']);
Route::get('/events/{event}/timers', [TimerController::class, 'show']);
Route::get('/timers/active', [TimerController::class, 'active']);

// ── Client Error Logging & Diagnostics ─────────────────────────────────────────
Route::post('/logs', [ErrorLogController::class, 'store'])->middleware('throttle:30,1');

Route::post('/payments', [PaymentController::class, 'store']);
Route::post('/vouchers/validate', [PaymentController::class, 'validateVoucher'])->middleware('throttle:30,1');
Route::get('/payments/{payment}/status', [PaymentController::class, 'status']);
// Hanya hidup di luar produksi; controllernya menolak saat APP_ENV=production.
Route::post('/payments/{payment}/simulate-paid', [PaymentController::class, 'simulatePaid'])
    ->middleware('throttle:10,1');

Route::post('/sessions', [SessionController::class, 'store']);
Route::post('/sessions/{session}/frame', [SessionController::class, 'setFrame']);
Route::post('/sessions/{session}/photos', [SessionController::class, 'uploadPhotos']);
Route::post('/sessions/{session}/generate-result', [SessionController::class, 'generateResult']);
Route::post('/sessions/{session}/finish', [SessionController::class, 'finish']);

Route::get('/results/{token}', [ResultController::class, 'show']);

// ── Payment Webhooks ──────────────────────────────────────────────────────────
Route::post('/webhooks/pakasir', [WebhookController::class, 'pakasir']);

// ── Admin REST API (Sanctum) ───────────────────────────────────────────────────
Route::prefix('admin')->group(function () {
    Route::post('/login', [AuthController::class, 'login'])->middleware('throttle:6,1');

    Route::middleware('auth:sanctum')->group(function () {
        Route::post('/logout', [AuthController::class, 'logout']);
        Route::get('/me', [AuthController::class, 'me']);

        // Events
        Route::apiResource('events', EventController::class);

        // Frames
        Route::apiResource('frames', App\Http\Controllers\Api\Admin\FrameController::class);

        // Filters
        Route::apiResource('filters', AdminFilterController::class);
        Route::patch('filters/{filter}/toggle', [AdminFilterController::class, 'toggle']);
        Route::post('filters/reorder', [AdminFilterController::class, 'reorder']);

        // Screen Content
        Route::apiResource('screens', ScreenConfigController::class);
        Route::post('screens/{screen}/preview', [ScreenConfigController::class, 'preview']);
        Route::post('screens/{screen}/publish', [ScreenConfigController::class, 'publish']);

        // Operational
        Route::get('transactions', [TransactionController::class, 'index']);
        Route::get('sessions', [AdminSessionController::class, 'index']);
        Route::get('sessions/{session}', [AdminSessionController::class, 'show']);
        Route::get('results', [AdminResultController::class, 'index']);

        // Hardware
        Route::apiResource('devices', DeviceController::class);
        Route::apiResource('printers', PrinterController::class)->only(['index', 'update']);

        // Reports
        Route::get('reports', [ReportController::class, 'index']);

        // Users
        Route::apiResource('users', UserController::class);
    });
});
