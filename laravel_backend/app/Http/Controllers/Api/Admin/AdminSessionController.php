<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Models\Session;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class AdminSessionController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $sessions = Session::with(['event', 'frame', 'filter', 'payment'])
            ->when($request->status, fn($q) => $q->where('status', $request->status))
            ->latest()
            ->paginate(20);

        return response()->json(['success' => true, 'data' => $sessions]);
    }

    public function show(Session $session): JsonResponse
    {
        $session->load(['event', 'frame', 'filter', 'payment', 'photos', 'result', 'printJobs']);
        return response()->json(['success' => true, 'data' => $session]);
    }
}
