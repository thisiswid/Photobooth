<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Models\Event;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class EventController extends Controller
{
    public function index(): JsonResponse
    {
        return response()->json(['success' => true, 'data' => Event::withCount('sessions')->latest()->get()]);
    }

    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'name'       => ['required', 'string', 'max:255'],
            'description'=> ['nullable', 'string'],
            'starts_at'  => ['nullable', 'date'],
            'ends_at'    => ['nullable', 'date'],
            'active'     => ['boolean'],
        ]);
        $event = Event::create($data);
        return response()->json(['success' => true, 'data' => $event], 201);
    }

    public function show(Event $event): JsonResponse
    {
        return response()->json(['success' => true, 'data' => $event->load(['frames', 'filters', 'devices'])]);
    }

    public function update(Request $request, Event $event): JsonResponse
    {
        $data = $request->validate([
            'name'       => ['sometimes', 'string', 'max:255'],
            'description'=> ['nullable', 'string'],
            'starts_at'  => ['nullable', 'date'],
            'ends_at'    => ['nullable', 'date'],
            'active'     => ['boolean'],
        ]);
        $event->update($data);
        return response()->json(['success' => true, 'data' => $event]);
    }

    public function destroy(Event $event): JsonResponse
    {
        $event->delete();
        return response()->json(['success' => true, 'data' => null]);
    }
}
