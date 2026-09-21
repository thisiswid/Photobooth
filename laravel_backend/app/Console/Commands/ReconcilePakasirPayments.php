<?php

namespace App\Console\Commands;

use App\Models\Payment;
use App\Services\PakasirReconciliationService;
use Illuminate\Console\Command;

class ReconcilePakasirPayments extends Command
{
    protected $signature = 'payments:reconcile-pakasir {--minutes=5 : Jeda minimum antar pemeriksaan} {--limit=100 : Maksimum transaksi per proses}';

    protected $description = 'Mencocokkan status transaksi pending dengan status resmi di Pakasir';

    public function handle(PakasirReconciliationService $service): int
    {
        $payments = Payment::query()
            ->where('status', 'pending')
            ->where('is_simulated', false)
            ->whereNotNull('xendit_payment_id')
            ->where('created_at', '>=', now()->subDays(7))
            ->where(function ($query): void {
                $query->whereNull('last_gateway_check_at')
                    ->orWhere('last_gateway_check_at', '<=', now()->subMinutes(max(1, (int) $this->option('minutes'))));
            })
            ->oldest()
            ->limit(max(1, min(500, (int) $this->option('limit'))))
            ->get();

        $counts = [];
        foreach ($payments as $payment) {
            $reconciliation = $service->reconcile($payment, 'scheduled');
            $result = $reconciliation?->result ?? 'error';
            $counts[$result] = ($counts[$result] ?? 0) + 1;
        }

        $this->info($payments->count().' transaksi diperiksa. '.collect($counts)->map(fn ($count, $result) => "{$result}: {$count}")->implode(', '));

        return self::SUCCESS;
    }
}
