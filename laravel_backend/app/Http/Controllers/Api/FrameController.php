<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Event;
use Illuminate\Http\JsonResponse;

class FrameController extends Controller
{
    public function index(Event $event): JsonResponse
    {
        $frames = $event->frames()->where('active', true)->get(['id', 'name', 'asset_url', 'pose_count', 'layout_config']);

        return response()->json(['success' => true, 'data' => $frames, 'message' => 'OK']);
    }
}
