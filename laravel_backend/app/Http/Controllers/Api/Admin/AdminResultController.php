<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Models\Result;
use Illuminate\Http\JsonResponse;

class AdminResultController extends Controller
{
    public function index(): JsonResponse
    {
        $results = Result::with('session.event')->latest()->paginate(20);
        return response()->json(['success' => true, 'data' => $results]);
    }
}
