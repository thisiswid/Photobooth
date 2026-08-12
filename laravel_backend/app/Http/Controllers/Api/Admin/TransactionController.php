<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Models\Payment;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class TransactionController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $payments = Payment::with('session.event')
            ->when($request->status, fn($q) => $q->where('status', $request->status))
            ->when($request->date, fn($q) => $q->whereDate('created_at', $request->date))
            ->latest()
            ->paginate(20);

        return response()->json(['success' => true, 'data' => $payments]);
    }
}
