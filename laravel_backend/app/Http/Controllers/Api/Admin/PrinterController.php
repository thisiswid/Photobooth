<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Models\PrintJob;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class PrinterController extends Controller
{
    public function index(): JsonResponse
    {
        // Returns recent print jobs grouped by printer
        $jobs = PrintJob::with('session')->latest()->paginate(20);
        return response()->json(['success' => true, 'data' => $jobs]);
    }

    public function update(Request $request, PrintJob $printer): JsonResponse
    {
        $printer->update($request->validate(['status' => ['in:pending,printing,done,failed']]));
        return response()->json(['success' => true, 'data' => $printer]);
    }
}
