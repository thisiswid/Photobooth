<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\PhotoSession;
use App\Models\PrintJob;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class AdminController extends Controller
{
    public function dashboard(): JsonResponse
    {
        return response()->json([
            'success' => true,
            'data'    => [
                'total_sessions' => PhotoSession::count(),
                'active_sessions' => PhotoSession::where('status', 'in_progress')->count(),
                'completed_sessions' => PhotoSession::where('status', 'completed')->count(),
            ],
        ]);
    }

    public function sessions(Request $request): JsonResponse
    {
        $sessions = PhotoSession::with(['photos', 'printJob'])
            ->latest()
            ->paginate($request->integer('per_page', 15));

        return response()->json([
            'success' => true,
            'data'    => $sessions,
        ]);
    }

    public function deleteSession(int $id): JsonResponse
    {
        $session = PhotoSession::findOrFail($id);
        $session->delete();

        return response()->json([
            'success' => true,
            'message' => 'Sesi berhasil dihapus.',
        ]);
    }

    public function reprint(int $id): JsonResponse
    {
        $session = PhotoSession::findOrFail($id);
        $printJob = PrintJob::create([
            'session_id' => $session->id,
            'status'     => 'pending',
        ]);

        \App\Jobs\PrintJob::dispatch($printJob);

        return response()->json([
            'success' => true,
            'data'    => $printJob,
            'message' => 'Cetak ulang berhasil dijadwalkan.',
        ]);
    }
}
