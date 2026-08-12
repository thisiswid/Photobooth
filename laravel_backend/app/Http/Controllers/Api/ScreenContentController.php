<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Event;
use App\Models\ScreenConfig;
use Illuminate\Http\JsonResponse;

class ScreenContentController extends Controller
{
    public function show(Event $event): JsonResponse
    {
        $screens = ScreenConfig::where('event_id', $event->id)
            ->where('status', 'active')
            ->with(['tutorialSteps' => fn($q) => $q->where('active', true)->orderBy('sort_order')])
            ->get()
            ->keyBy('screen_type');

        return response()->json([
            'success' => true,
            'data'    => [
                'welcome'  => $screens->get('welcome'),
                'tutorial' => $screens->get('tutorial'),
            ],
            'message' => 'OK',
        ]);
    }
}
