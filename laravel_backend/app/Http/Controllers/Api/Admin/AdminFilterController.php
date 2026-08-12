<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Models\Filter;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class AdminFilterController extends Controller
{
    public function index(): JsonResponse
    {
        return response()->json(['success' => true, 'data' => Filter::with('event')->orderBy('sort_order')->get()]);
    }

    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'event_id'      => ['nullable', 'exists:events,id'],
            'name'          => ['required', 'string', 'max:255'],
            'thumbnail_url' => ['nullable', 'string'],
            'parameters'    => ['nullable', 'string'],
            'sort_order'    => ['integer'],
            'active'        => ['boolean'],
        ]);
        return response()->json(['success' => true, 'data' => Filter::create($data)], 201);
    }

    public function show(Filter $filter): JsonResponse
    {
        return response()->json(['success' => true, 'data' => $filter]);
    }

    public function update(Request $request, Filter $filter): JsonResponse
    {
        $filter->update($request->validate([
            'event_id'      => ['nullable', 'exists:events,id'],
            'name'          => ['sometimes', 'string', 'max:255'],
            'thumbnail_url' => ['nullable', 'string'],
            'parameters'    => ['nullable', 'string'],
            'sort_order'    => ['integer'],
            'active'        => ['boolean'],
        ]));
        return response()->json(['success' => true, 'data' => $filter]);
    }

    public function destroy(Filter $filter): JsonResponse
    {
        $filter->delete();
        return response()->json(['success' => true, 'data' => null]);
    }

    public function toggle(Filter $filter): JsonResponse
    {
        $filter->update(['active' => !$filter->active]);
        return response()->json(['success' => true, 'data' => $filter]);
    }

    public function reorder(Request $request): JsonResponse
    {
        $request->validate(['filters' => ['required', 'array'], 'filters.*.id' => ['required', 'exists:filters,id'], 'filters.*.sort_order' => ['required', 'integer']]);
        foreach ($request->filters as $item) {
            Filter::where('id', $item['id'])->update(['sort_order' => $item['sort_order']]);
        }
        return response()->json(['success' => true, 'data' => null]);
    }
}
