<?php

namespace App\Console\Commands;

use App\Models\Payment;
use Illuminate\Console\Command;

class SettlePakasirPayments extends Command
{
    protected $signature = 'payments:settle-pakasir';

    protected $description = 'Memindahkan pembayaran QRIS H+1 yang jatuh tempo ke saldo tersedia';

    public function handle(): int
    {
        $settledAt = now();
        $count = Payment::query()
            ->where('status', 'paid')
            ->where('is_simulated', false)
            ->where('settlement_status', 'pending')
            ->whereNotNull('settlement_due_at')
            ->where('settlement_due_at', '<=', $settledAt)
            ->update([
                'settlement_status' => 'settled',
                'settled_at' => $settledAt,
                'updated_at' => $settledAt,
            ]);

        $this->info("{$count} pembayaran Pakasir berhasil disettlement.");

        return self::SUCCESS;
    }
}
