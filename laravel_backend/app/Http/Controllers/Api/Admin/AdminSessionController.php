<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Models\Session;
use App\Traits\ScopesToCafe;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class AdminSessionController extends Controller
{
    use ScopesToCafe;

    public function index(Request $request): JsonResponse
    {
        $sessions = $this->scopeOwn(Session::query())
            ->with(['event', 'frame', 'filter', 'payment'])
            ->when($request->status, fn($q) => $q->where('status', $request->status))
            ->latest()
            ->paginate(20);

        return response()->json(['success' => true, 'data' => $sessions]);
    }

    public function show(Session $session): JsonResponse
    {
        $this->guardCafe($session->cafe_id);

        $session->load(['event', 'frame', 'filter', 'payment', 'photos', 'result', 'printJobs']);
        return response()->json(['success' => true, 'data' => $session]);
    }
}
