<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Models\Payment;
use App\Models\Session;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class ReportController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $period = $request->get('period', 'today');

        $query = match($period) {
            'today'   => fn($q) => $q->whereDate('created_at', today()),
            'week'    => fn($q) => $q->whereBetween('created_at', [now()->startOfWeek(), now()->endOfWeek()]),
            'month'   => fn($q) => $q->whereMonth('created_at', now()->month),
            default   => fn($q) => $q->whereDate('created_at', today()),
        };

        $totalSessions  = Session::tap($query)->count();
        $finishedSessions = Session::tap($query)->where('status', 'finished')->count();
        $totalRevenue   = Payment::tap($query)->where('status', 'paid')->sum('amount');
        $paidCount      = Payment::tap($query)->where('status', 'paid')->count();
        $failedCount    = Payment::tap($query)->where('status', 'failed')->count();

        // Sessions per day (last 7 days)
        $dailyData = collect(range(6, 0))->map(function ($daysAgo) {
            $date = today()->subDays($daysAgo);
            return [
                'date'  => $date->format('Y-m-d'),
                'label' => $date->format('d M'),
                'count' => Session::whereDate('created_at', $date)->count(),
            ];
        });

        return response()->json([
            'success' => true,
            'data'    => [
                'period'           => $period,
                'total_sessions'   => $totalSessions,
                'finished_sessions'=> $finishedSessions,
                'total_revenue'    => $totalRevenue,
                'paid_count'       => $paidCount,
                'failed_count'     => $failedCount,
                'daily_sessions'   => $dailyData,
            ],
        ]);
    }
}
