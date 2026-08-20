<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Event;
use App\Models\TimerSetting;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class TimerController extends Controller
{
    /**
     * Get active timer setting by Event or Cafe.
     */
    public function show(Event $event): JsonResponse
    {
        $setting = TimerSetting::where('event_id', $event->id)
            ->where('is_active', true)
            ->first()
            ?? TimerSetting::resolveForCafe($event->cafe_id);

        return response()->json([
            'success' => true,
            'data'    => $setting,
        ]);
    }

    /**
     * Get active timer setting globally or for authenticated cafe.
     */
    public function active(Request $request): JsonResponse
    {
        $cafeId = $request->user()?->cafe_id ?? $request->query('cafe_id');
        $setting = TimerSetting::resolveForCafe($cafeId ? (int)$cafeId : null);

        return response()->json([
            'success' => true,
            'data'    => $setting,
        ]);
    }
}
