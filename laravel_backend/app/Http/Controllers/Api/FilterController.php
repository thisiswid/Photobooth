<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Event;
use Illuminate\Http\JsonResponse;

class FilterController extends Controller
{
    public function index(Event $event): JsonResponse
    {
        $filters = $event->filters()
            ->where('active', true)
            ->orderBy('sort_order')
            ->get(['id', 'name', 'thumbnail_url', 'parameters']);

        if ($filters->isEmpty()) {
            $filters = \App\Models\Filter::where('active', true)
                ->orderBy('sort_order')
                ->get(['id', 'name', 'thumbnail_url', 'parameters']);
        }

        return response()->json(['success' => true, 'data' => $filters, 'message' => 'OK']);
    }
}
