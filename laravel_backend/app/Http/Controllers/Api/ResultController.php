<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Result;
use Illuminate\Http\JsonResponse;

class ResultController extends Controller
{
    public function show(string $token): JsonResponse
    {
        $result = Result::where('qr_token', $token)
            ->where('expires_at', '>', now())
            ->with('session.photos')
            ->firstOrFail();

        $photos = $result->session->photos
            ->where('type', 'raw')
            ->map(fn($p) => ['url' => $p->file_url])
            ->values();

        return response()->json([
            'success' => true,
            'data'    => [
                'final_url'  => $result->final_url,
                'gif_url'    => $result->gif_url,
                'photos'     => $photos,
                'expires_at' => $result->expires_at,
            ],
            'message' => 'OK',
        ]);
    }
}
