<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Models\ScreenConfig;
use App\Traits\ScopesToCafe;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class ScreenConfigController extends Controller
{
    use ScopesToCafe;

    public function index(): JsonResponse
    {
        $screens = $this->scopeViaEvent(ScreenConfig::query())->with('event')->latest()->get();
        return response()->json(['success' => true, 'data' => $screens]);
    }

    public function store(Request $request): JsonResponse
    {
        $this->requireAdmin();

        $data = $request->validate([
            'event_id'       => ['nullable', 'exists:events,id'],
            'screen_type'    => ['required', 'in:welcome,tutorial'],
            'title'          => ['nullable', 'string'],
            'description'    => ['nullable', 'string'],
            'background_url' => ['nullable', 'string'],
            'button_text'    => ['nullable', 'string'],
        ]);
        $this->guardEventId($data['event_id'] ?? null);

        $data['status'] = 'draft';
        $data['version'] = 1;
        return response()->json(['success' => true, 'data' => ScreenConfig::create($data)], 201);
    }

    public function show(ScreenConfig $screen): JsonResponse
    {
        $this->guardCafe($screen->event?->cafe_id);
        return response()->json(['success' => true, 'data' => $screen->load('tutorialSteps')]);
    }

    public function update(Request $request, ScreenConfig $screen): JsonResponse
    {
        $this->requireAdmin();
        $this->guardCafe($screen->event?->cafe_id);

        $screen->update($request->validate([
            'title'          => ['nullable', 'string'],
            'description'    => ['nullable', 'string'],
            'background_url' => ['nullable', 'string'],
            'button_text'    => ['nullable', 'string'],
        ]));
        return response()->json(['success' => true, 'data' => $screen]);
    }

    public function destroy(ScreenConfig $screen): JsonResponse
    {
        $this->requireAdmin();
        $this->guardCafe($screen->event?->cafe_id);

        $screen->delete();
        return response()->json(['success' => true, 'data' => null]);
    }

    public function preview(ScreenConfig $screen): JsonResponse
    {
        $this->requireAdmin();
        $this->guardCafe($screen->event?->cafe_id);

        $screen->update(['status' => 'preview']);
        return response()->json(['success' => true, 'data' => $screen, 'message' => 'Dipindah ke Preview.']);
    }

    public function publish(ScreenConfig $screen): JsonResponse
    {
        $this->requireAdmin();
        $this->guardCafe($screen->event?->cafe_id);

        ScreenConfig::where('screen_type', $screen->screen_type)
            ->where('event_id', $screen->event_id)
            ->where('status', 'active')
            ->update(['status' => 'published']);

        $screen->update(['status' => 'active', 'version' => $screen->version + 1]);
        return response()->json(['success' => true, 'data' => $screen, 'message' => 'Screen dipublish.']);
    }
}
