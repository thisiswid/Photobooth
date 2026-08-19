<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Event;
use App\Models\Frame;
use Illuminate\Http\JsonResponse;

class FrameController extends Controller
{
    public function index(Event $event): JsonResponse
    {
        if ($event->id == 1) {
            $frames = Frame::where('active', true)
                ->with('event:id,name')
                ->latest()
                ->get(['id', 'event_id', 'name', 'asset_url', 'pose_count', 'layout_config']);
        } else {
            $frames = $event->frames()
                ->where('active', true)
                ->with('event:id,name')
                ->latest()
                ->get(['id', 'event_id', 'name', 'asset_url', 'pose_count', 'layout_config']);

            if ($frames->isEmpty()) {
                $frames = Frame::where('active', true)
                    ->with('event:id,name')
                    ->latest()
                    ->get(['id', 'event_id', 'name', 'asset_url', 'pose_count', 'layout_config']);
            }
        }

        // Flatten layout_config fields to top-level for Flutter client
        $data = $frames->map(function (Frame $frame) {
            $config = $frame->layout_config ?? [];

            $layoutType       = $config['layout_type']        ?? 'single';
            $slotCount        = $config['slot_count']          ?? $frame->pose_count;
            $rightColumnOrder = $config['right_column_order']  ?? null;
            $slots            = $config['slots']               ?? null;

            return [
                'id'                  => $frame->id,
                'name'                => $frame->name,
                'asset_url'           => $frame->asset_url,
                'pose_count'          => $frame->pose_count,
                'layout_type'         => $layoutType,
                'slot_count'          => $slotCount,
                'right_column_order'  => $rightColumnOrder,
                'slots'               => $slots,
                'layout_config'       => $frame->layout_config, // keep for backward compat
                'event'               => $frame->event ? ['id' => $frame->event->id, 'name' => $frame->event->name] : null,
            ];
        });

        return response()->json([
            'success' => true,
            'data'    => $data,
            'message' => 'OK',
        ]);
    }
}
