<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Models\PrintJob;
use App\Traits\ScopesToCafe;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class PrinterController extends Controller
{
    use ScopesToCafe;

    public function index(): JsonResponse
    {
        $jobs = $this->scopeViaSession(PrintJob::query())->with('session')->latest()->paginate(20);
        return response()->json(['success' => true, 'data' => $jobs]);
    }

    public function update(Request $request, PrintJob $printer): JsonResponse
    {
        $this->guardCafe($printer->session?->cafe_id);

        $printer->update($request->validate(['status' => ['in:pending,printing,done,failed']]));
        return response()->json(['success' => true, 'data' => $printer]);
    }
}
