<?php

use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\ScreenContentController;
use App\Http\Controllers\Api\FrameController;
use App\Http\Controllers\Api\FilterController;
use App\Http\Controllers\Api\PaymentController;
use App\Http\Controllers\Api\SessionController;
use App\Http\Controllers\Api\ResultController;
use App\Http\Controllers\Api\WebhookController;
use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| LumaBooth API Routes
|--------------------------------------------------------------------------
*/

// ── Customer ──────────────────────────────────────────────────────────────────
Route::get('/events/{event}/screen-content', [ScreenContentController::class, 'show']);
Route::get('/events/{event}/frames', [FrameController::class, 'index']);
Route::get('/events/{event}/filters', [FilterController::class, 'index']);

Route::post('/payments', [PaymentController::class, 'store']);
Route::get('/payments/{payment}/status', [PaymentController::class, 'status']);

Route::post('/sessions', [SessionController::class, 'store']);
Route::post('/sessions/{session}/frame', [SessionController::class, 'setFrame']);
Route::post('/sessions/{session}/photos', [SessionController::class, 'uploadPhotos']);
Route::post('/sessions/{session}/generate-result', [SessionController::class, 'generateResult']);
Route::post('/sessions/{session}/finish', [SessionController::class, 'finish']);

Route::get('/results/{token}', [ResultController::class, 'show']);

// ── Xendit Webhook ─────────────────────────────────────────────────────────────
Route::post('/webhooks/xendit/payment', [WebhookController::class, 'xendit']);

// ── Admin REST API (Sanctum) ───────────────────────────────────────────────────
Route::prefix('admin')->group(function () {
    Route::post('/login', [AuthController::class, 'login']);

    Route::middleware('auth:sanctum')->group(function () {
        Route::post('/logout', [AuthController::class, 'logout']);
        Route::get('/me', [AuthController::class, 'me']);

        // Events
        Route::apiResource('events', \App\Http\Controllers\Api\Admin\EventController::class);

        // Frames
        Route::apiResource('frames', \App\Http\Controllers\Api\Admin\FrameController::class);

        // Filters
        Route::apiResource('filters', \App\Http\Controllers\Api\Admin\AdminFilterController::class);
        Route::patch('filters/{filter}/toggle', [\App\Http\Controllers\Api\Admin\AdminFilterController::class, 'toggle']);
        Route::post('filters/reorder', [\App\Http\Controllers\Api\Admin\AdminFilterController::class, 'reorder']);

        // Screen Content
        Route::apiResource('screens', \App\Http\Controllers\Api\Admin\ScreenConfigController::class);
        Route::post('screens/{screen}/preview', [\App\Http\Controllers\Api\Admin\ScreenConfigController::class, 'preview']);
        Route::post('screens/{screen}/publish', [\App\Http\Controllers\Api\Admin\ScreenConfigController::class, 'publish']);

        // Operational
        Route::get('transactions', [\App\Http\Controllers\Api\Admin\TransactionController::class, 'index']);
        Route::get('sessions', [\App\Http\Controllers\Api\Admin\AdminSessionController::class, 'index']);
        Route::get('sessions/{session}', [\App\Http\Controllers\Api\Admin\AdminSessionController::class, 'show']);
        Route::get('results', [\App\Http\Controllers\Api\Admin\AdminResultController::class, 'index']);

        // Hardware
        Route::apiResource('devices', \App\Http\Controllers\Api\Admin\DeviceController::class);
        Route::apiResource('printers', \App\Http\Controllers\Api\Admin\PrinterController::class)->only(['index', 'update']);

        // Reports
        Route::get('reports', [\App\Http\Controllers\Api\Admin\ReportController::class, 'index']);

        // Users
        Route::apiResource('users', \App\Http\Controllers\Api\Admin\UserController::class);
    });
});
