<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Models\Device;
use App\Traits\ScopesToCafe;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class DeviceController extends Controller
{
    use ScopesToCafe;

    public function index(): JsonResponse
    {
        $devices = $this->scopeOwn(Device::query())->with('event')->get();
        return response()->json(['success' => true, 'data' => $devices]);
    }

    public function store(Request $request): JsonResponse
    {
        $this->requireAdmin();

        $data = $request->validate([
            'event_id' => ['nullable', 'exists:events,id'],
            'name'     => ['required', 'string', 'max:255'],
            'platform' => ['in:android,ios,web'],
            'status'   => ['in:active,inactive'],
        ]);
        $this->guardEventId($data['event_id'] ?? null);

        return response()->json(['success' => true, 'data' => Device::create($this->withCafeId($data))], 201);
    }

    public function show(Device $device): JsonResponse
    {
        $this->guardCafe($device->cafe_id);
        return response()->json(['success' => true, 'data' => $device]);
    }

    public function update(Request $request, Device $device): JsonResponse
    {
        $this->requireAdmin();
        $this->guardCafe($device->cafe_id);

        $data = $request->validate([
            'event_id' => ['nullable', 'exists:events,id'],
            'name'     => ['sometimes', 'string'],
            'platform' => ['in:android,ios,web'],
            'status'   => ['in:active,inactive'],
        ]);
        $this->guardEventId($data['event_id'] ?? null);

        $device->update($data);
        return response()->json(['success' => true, 'data' => $device]);
    }

    public function destroy(Device $device): JsonResponse
    {
        $this->requireAdmin();
        $this->guardCafe($device->cafe_id);

        $device->delete();
        return response()->json(['success' => true, 'data' => null]);
    }
}
