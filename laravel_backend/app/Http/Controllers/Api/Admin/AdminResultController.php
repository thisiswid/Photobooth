<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Models\Result;
use App\Traits\ScopesToCafe;
use Illuminate\Http\JsonResponse;

class AdminResultController extends Controller
{
    use ScopesToCafe;

    public function index(): JsonResponse
    {
        $results = $this->scopeViaSession(Result::query())
            ->with('session.event')
            ->latest()
            ->paginate(20);

        return response()->json(['success' => true, 'data' => $results]);
    }
}
