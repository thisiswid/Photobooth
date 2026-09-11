<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Models\Frame;
use App\Traits\ScopesToCafe;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class FrameController extends Controller
{
    use ScopesToCafe;

    public function index(): JsonResponse
    {
        $frames = $this->scopeViaEvent(Frame::query())->with('event')->latest()->get();
        return response()->json(['success' => true, 'data' => $frames]);
    }

    public function store(Request $request): JsonResponse
    {
        $this->requireAdmin();

        $data = $request->validate([
            'event_id'     => ['nullable', 'exists:events,id'],
            'name'         => ['required', 'string', 'max:255'],
            'asset_url'    => ['nullable', 'string'],
            'pose_count'   => ['integer', 'min:1', 'max:6'],
            'layout_config'=> ['nullable', 'array'],
            'active'       => ['boolean'],
        ]);
        $this->guardEventId($data['event_id'] ?? null);

        return response()->json(['success' => true, 'data' => Frame::create($data)], 201);
    }

    public function show(Frame $frame): JsonResponse
    {
        $this->guardCafe($frame->event?->cafe_id);
        return response()->json(['success' => true, 'data' => $frame->load('event')]);
    }

    public function update(Request $request, Frame $frame): JsonResponse
    {
        $this->requireAdmin();
        $this->guardCafe($frame->event?->cafe_id);

        $data = $request->validate([
            'event_id'     => ['nullable', 'exists:events,id'],
            'name'         => ['sometimes', 'string', 'max:255'],
            'asset_url'    => ['nullable', 'string'],
            'pose_count'   => ['sometimes', 'integer', 'min:1', 'max:6'],
            'layout_config'=> ['nullable', 'array'],
            'active'       => ['boolean'],
        ]);
        $this->guardEventId($data['event_id'] ?? null);

        $frame->update($data);
        return response()->json(['success' => true, 'data' => $frame]);
    }

    public function destroy(Frame $frame): JsonResponse
    {
        $this->requireAdmin();
        $this->guardCafe($frame->event?->cafe_id);

        $frame->delete();
        return response()->json(['success' => true, 'data' => null]);
    }
}
