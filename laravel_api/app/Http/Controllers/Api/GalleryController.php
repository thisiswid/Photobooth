<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\PhotoSession;
use Illuminate\Http\JsonResponse;

class GalleryController extends Controller
{
    /**
     * Public gallery endpoint — no authentication required.
     * Returns session photos and download links for the customer.
     */
    public function show(string $code): JsonResponse
    {
        $session = PhotoSession::with(['photos', 'package'])
                               ->where('session_code', $code)
                               ->where('payment_status', 'paid')
                               ->firstOrFail();

        // Respect expiry
        $expiryDays = config('photobooth.gallery_expiry_days', 30);
        if ($session->created_at->diffInDays(now()) > $expiryDays) {
            return response()->json([
                'success' => false,
                'data'    => null,
                'message' => 'Link galeri sudah kedaluwarsa.',
            ], 410);
        }

        $baseUrl = request()->getSchemeAndHttpHost() . '/storage/';

        $photos = $session->photos()
                          ->where('photo_type', 'individual')
                          ->orderBy('captured_at')
                          ->get()
                          ->map(fn($p) => [
                              'id'  => $p->id,
                              'url' => $baseUrl . $p->file_path,
                          ]);

        return response()->json([
            'success' => true,
            'data'    => [
                'session_code' => $session->session_code,
                'package'      => $session->package?->name,
                'photos'       => $photos,
                'strip_url'    => $session->strip_path ? $baseUrl . $session->strip_path : null,
                'gif_url'      => $session->gif_path   ? $baseUrl . $session->gif_path   : null,
                'expired_at'   => $session->created_at->addDays($expiryDays)->toIso8601String(),
            ],
            'message' => 'OK',
        ]);
    }
}
