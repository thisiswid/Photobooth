<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Models\Frame;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class FrameController extends Controller
{
    public function index(): JsonResponse
    {
        return response()->json(['success' => true, 'data' => Frame::with('event')->latest()->get()]);
    }

    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'event_id'  => ['nullable', 'exists:events,id'],
            'name'      => ['required', 'string', 'max:255'],
            'asset_url' => ['nullable', 'string'],
            'active'    => ['boolean'],
        ]);
        return response()->json(['success' => true, 'data' => Frame::create($data)], 201);
    }

    public function show(Frame $frame): JsonResponse
    {
        return response()->json(['success' => true, 'data' => $frame->load('event')]);
    }

    public function update(Request $request, Frame $frame): JsonResponse
    {
        $frame->update($request->validate([
            'event_id'  => ['nullable', 'exists:events,id'],
            'name'      => ['sometimes', 'string', 'max:255'],
            'asset_url' => ['nullable', 'string'],
            'active'    => ['boolean'],
        ]));
        return response()->json(['success' => true, 'data' => $frame]);
    }

    public function destroy(Frame $frame): JsonResponse
    {
        $frame->delete();
        return response()->json(['success' => true, 'data' => null]);
    }
}
