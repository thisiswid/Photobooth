<?php

use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\GalleryController;
use App\Http\Controllers\Api\PhotoController;
use App\Http\Controllers\Api\PrintController;
use App\Http\Controllers\Api\ResultController;
use App\Http\Controllers\Api\SessionController;
use App\Http\Controllers\Api\AdminController;
use App\Http\Controllers\Api\TemplateController;
use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| Fakultas Kopi Photobooth API Routes
|--------------------------------------------------------------------------
*/

// ── Public ────────────────────────────────────────────────────────────────────
Route::post('/login', [AuthController::class, 'login']);
Route::get('/gallery/{code}', [GalleryController::class, 'show']);
Route::get('/packages', [\App\Http\Controllers\Api\PackageController::class, 'index']);

// ── Kiosk Session (no auth — kiosk runs unauthenticated) ──────────────────────
Route::post('/session/create', [SessionController::class, 'create']);
Route::get('/session/{code}', [SessionController::class, 'show']);
Route::patch('/session/{code}/payment', [SessionController::class, 'updatePayment']);
Route::patch('/session/{code}/finalize', [SessionController::class, 'finalize']);
Route::post('/session/{code}/photo', [PhotoController::class, 'upload']);
Route::get('/session/{code}/photos', [PhotoController::class, 'index']);
Route::delete('/photo/{id}', [PhotoController::class, 'destroy']);
Route::post('/session/{code}/generate', [ResultController::class, 'generate']);
Route::get('/generate/{jobId}/status', [ResultController::class, 'status']);
Route::get('/session/{code}/download/{type}', [ResultController::class, 'download']);
Route::post('/session/{code}/print', [PrintController::class, 'print']);
Route::get('/print/{printId}/status', [PrintController::class, 'status']);
Route::post('/print/{printId}/retry', [PrintController::class, 'retry']);

// ── Admin (Sanctum) ───────────────────────────────────────────────────────────
Route::middleware('auth:sanctum')->prefix('admin')->group(function () {
    Route::post('/auth/logout', [AuthController::class, 'logout']);
    Route::get('/auth/me', [AuthController::class, 'me']);

    Route::get('/dashboard', [AdminController::class, 'dashboard']);
    Route::get('/sessions', [AdminController::class, 'sessions']);
    Route::delete('/session/{id}', [AdminController::class, 'deleteSession']);
    Route::post('/session/{id}/reprint', [AdminController::class, 'reprint']);

    Route::get('/frames', [TemplateController::class, 'frames']);
    Route::post('/frames', [TemplateController::class, 'storeFrame']);
    Route::delete('/frames/{id}', [TemplateController::class, 'deleteFrame']);
    Route::get('/stickers', [TemplateController::class, 'stickers']);
    Route::post('/stickers', [TemplateController::class, 'storeSticker']);
    Route::get('/layouts', [TemplateController::class, 'layouts']);
});
