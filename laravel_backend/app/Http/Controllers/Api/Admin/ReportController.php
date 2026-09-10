<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Models\Payment;
use App\Models\Session;
use App\Traits\ScopesToCafe;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class ReportController extends Controller
{
    use ScopesToCafe;

    /** Sesi milik cafe pemanggil, dibatasi periode. */
    protected function sessions(string $period): Builder
    {
        return $this->applyPeriod($this->scopeOwn(Session::query()), $period);
    }

    /** Pembayaran milik cafe pemanggil, dibatasi periode. */
    protected function payments(string $period): Builder
    {
        return $this->applyPeriod($this->scopeViaSession(Payment::query()), $period);
    }

    protected function applyPeriod(Builder $query, string $period): Builder
    {
        return match ($period) {
            'week'  => $query->whereBetween('created_at', [now()->startOfWeek(), now()->endOfWeek()]),
            'month' => $query->whereMonth('created_at', now()->month)->whereYear('created_at', now()->year),
            default => $query->whereDate('created_at', today()),
        };
    }

    public function index(Request $request): JsonResponse
    {
        $period = $request->get('period', 'today');

        $totalSessions    = $this->sessions($period)->count();
        $finishedSessions = $this->sessions($period)->where('status', 'finished')->count();
        $totalRevenue     = $this->payments($period)->where('status', 'paid')->sum('amount');
        $paidCount        = $this->payments($period)->where('status', 'paid')->count();
        $failedCount      = $this->payments($period)->where('status', 'failed')->count();

        // Sesi per hari (7 hari terakhir), juga dibatasi ke cafe pemanggil.
        $dailyData = collect(range(6, 0))->map(function ($daysAgo) {
            $date = today()->subDays($daysAgo);
            return [
                'date'  => $date->format('Y-m-d'),
                'label' => $date->format('d M'),
                'count' => $this->scopeOwn(Session::query())->whereDate('created_at', $date)->count(),
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
