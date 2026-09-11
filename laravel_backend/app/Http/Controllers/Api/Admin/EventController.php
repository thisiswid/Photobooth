<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Models\Event;
use App\Traits\ScopesToCafe;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class EventController extends Controller
{
    use ScopesToCafe;

    public function index(): JsonResponse
    {
        $events = $this->scopeOwn(Event::query())->withCount('sessions')->latest()->get();
        return response()->json(['success' => true, 'data' => $events]);
    }

    public function store(Request $request): JsonResponse
    {
        $this->requireAdmin();

        $data = $request->validate([
            'name'       => ['required', 'string', 'max:255'],
            'description'=> ['nullable', 'string'],
            'starts_at'  => ['nullable', 'date'],
            'ends_at'    => ['nullable', 'date'],
            'active'     => ['boolean'],
        ]);
        $event = Event::create($this->withCafeId($data));
        return response()->json(['success' => true, 'data' => $event], 201);
    }

    public function show(Event $event): JsonResponse
    {
        $this->guardCafe($event->cafe_id);
        return response()->json(['success' => true, 'data' => $event->load(['frames', 'filters', 'devices'])]);
    }

    public function update(Request $request, Event $event): JsonResponse
    {
        $this->requireAdmin();
        $this->guardCafe($event->cafe_id);

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
        $this->requireAdmin();
        $this->guardCafe($event->cafe_id);

        $event->delete();
        return response()->json(['success' => true, 'data' => null]);
    }
}
