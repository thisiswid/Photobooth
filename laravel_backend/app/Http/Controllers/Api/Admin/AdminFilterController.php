<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Models\Filter;
use App\Traits\ScopesToCafe;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class AdminFilterController extends Controller
{
    use ScopesToCafe;

    public function index(): JsonResponse
    {
        $filters = $this->scopeViaEvent(Filter::query())->with('event')->orderBy('sort_order')->get();
        return response()->json(['success' => true, 'data' => $filters]);
    }

    public function store(Request $request): JsonResponse
    {
        $this->requireAdmin();

        $data = $request->validate([
            'event_id'      => ['nullable', 'exists:events,id'],
            'name'          => ['required', 'string', 'max:255'],
            'thumbnail_url' => ['nullable', 'string'],
            'parameters'    => ['nullable', 'string'],
            'sort_order'    => ['integer'],
            'active'        => ['boolean'],
        ]);
        $this->guardEventId($data['event_id'] ?? null);

        return response()->json(['success' => true, 'data' => Filter::create($data)], 201);
    }

    public function show(Filter $filter): JsonResponse
    {
        $this->guardCafe($filter->event?->cafe_id);
        return response()->json(['success' => true, 'data' => $filter]);
    }

    public function update(Request $request, Filter $filter): JsonResponse
    {
        $this->requireAdmin();
        $this->guardCafe($filter->event?->cafe_id);

        $data = $request->validate([
            'event_id'      => ['nullable', 'exists:events,id'],
            'name'          => ['sometimes', 'string', 'max:255'],
            'thumbnail_url' => ['nullable', 'string'],
            'parameters'    => ['nullable', 'string'],
            'sort_order'    => ['integer'],
            'active'        => ['boolean'],
        ]);
        $this->guardEventId($data['event_id'] ?? null);

        $filter->update($data);
        return response()->json(['success' => true, 'data' => $filter]);
    }

    public function destroy(Filter $filter): JsonResponse
    {
        $this->requireAdmin();
        $this->guardCafe($filter->event?->cafe_id);

        $filter->delete();
        return response()->json(['success' => true, 'data' => null]);
    }

    public function toggle(Filter $filter): JsonResponse
    {
        $this->requireAdmin();
        $this->guardCafe($filter->event?->cafe_id);

        $filter->update(['active' => !$filter->active]);
        return response()->json(['success' => true, 'data' => $filter]);
    }

    public function reorder(Request $request): JsonResponse
    {
        $this->requireAdmin();

        $request->validate([
            'filters'              => ['required', 'array'],
            'filters.*.id'         => ['required', 'exists:filters,id'],
            'filters.*.sort_order' => ['required', 'integer'],
        ]);

        // Urutkan hanya filter milik cafe pemanggil.
        foreach ($request->filters as $item) {
            $this->scopeViaEvent(Filter::query())
                ->where('id', $item['id'])
                ->update(['sort_order' => $item['sort_order']]);
        }

        return response()->json(['success' => true, 'data' => null]);
    }
}
