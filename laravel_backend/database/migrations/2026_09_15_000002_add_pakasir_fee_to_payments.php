<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('payments', function (Blueprint $table) {
            $table->decimal('provider_fee', 12, 2)->default(0)->after('amount');
            $table->decimal('net_amount', 12, 2)->default(0)->after('provider_fee');
        });

        // Backfill histori secara portable untuk PostgreSQL, MySQL, dan SQLite.
        $calculateQrisFee = static function ($amount, ?string $paymentMethod, bool $isSimulated): int {
            $amount = max(0, (int) round((float) $amount));
            $method = strtolower(trim($paymentMethod ?: 'qris'));

            if ($isSimulated || $amount === 0 || ! str_starts_with($method, 'qris')) {
                return 0;
            }

            return $amount > 105000
                ? (int) round($amount * 0.01)
                : (int) round($amount * 0.007) + 310;
        };

        DB::table('payments')
            ->select(['id', 'amount', 'payment_method', 'is_simulated'])
            ->orderBy('id')
            ->chunkById(500, function ($payments) use ($calculateQrisFee): void {
                foreach ($payments as $payment) {
                    $fee = $calculateQrisFee(
                        $payment->amount,
                        $payment->payment_method,
                        (bool) $payment->is_simulated,
                    );

                    DB::table('payments')->where('id', $payment->id)->update([
                        'provider_fee' => $fee,
                        'net_amount' => max(0, (int) round((float) $payment->amount) - $fee),
                    ]);
                }
            });
    }

    public function down(): void
    {
        Schema::table('payments', function (Blueprint $table) {
            $table->dropColumn(['provider_fee', 'net_amount']);
        });
    }
};
