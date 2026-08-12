<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Models\Device;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class DeviceController extends Controller
{
    public function index(): JsonResponse
    {
        return response()->json(['success' => true, 'data' => Device::with('event')->get()]);
    }

    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'event_id' => ['nullable', 'exists:events,id'],
            'name'     => ['required', 'string', 'max:255'],
            'platform' => ['in:android,ios,web'],
            'status'   => ['in:active,inactive'],
        ]);
        return response()->json(['success' => true, 'data' => Device::create($data)], 201);
    }

    public function show(Device $device): JsonResponse
    {
        return response()->json(['success' => true, 'data' => $device]);
    }

    public function update(Request $request, Device $device): JsonResponse
    {
        $device->update($request->validate([
            'event_id' => ['nullable', 'exists:events,id'],
            'name'     => ['sometimes', 'string'],
            'platform' => ['in:android,ios,web'],
            'status'   => ['in:active,inactive'],
        ]));
        return response()->json(['success' => true, 'data' => $device]);
    }

    public function destroy(Device $device): JsonResponse
    {
        $device->delete();
        return response()->json(['success' => true, 'data' => null]);
    }
}
