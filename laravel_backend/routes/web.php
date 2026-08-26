<?php

use App\Http\Controllers\Web\DownloadController;
use Illuminate\Support\Facades\Route;

Route::get('/', function () {
    return view('landing');
});

// ── Customer QR Code Download Portal ─────────────────────────────────────────
Route::get('/d/{token}', [DownloadController::class, 'show'])->name('download.show');
Route::get('/d/{token}/strip', [DownloadController::class, 'downloadStrip'])->name('download.strip');
Route::get('/d/{token}/raw-strip', [DownloadController::class, 'downloadRawStrip'])->name('download.raw_strip');
Route::get('/d/{token}/video', [DownloadController::class, 'downloadVideo'])->name('download.video');
Route::get('/d/{token}/gif', [DownloadController::class, 'downloadGif'])->name('download.gif');
Route::get('/d/{token}/photo/{photoId}', [DownloadController::class, 'downloadPhoto'])->name('download.photo');
