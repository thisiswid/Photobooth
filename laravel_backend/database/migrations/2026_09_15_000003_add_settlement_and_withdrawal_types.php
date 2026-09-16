<?php

use Carbon\CarbonImmutable;
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('payments', function (Blueprint $table) {
            $table->string('settlement_status')->default('not_applicable')->after('net_amount');
            $table->timestamp('settlement_due_at')->nullable()->after('settlement_status');
            $table->timestamp('settled_at')->nullable()->after('settlement_due_at');
            $table->index(['settlement_status', 'settlement_due_at'], 'payments_settlement_due_idx');
        });

        Schema::table('withdrawals', function (Blueprint $table) {
            $table->string('type')->default('manual')->after('user_id');
            $table->unsignedBigInteger('admin_fee')->default(0)->after('amount');
            $table->unsignedBigInteger('net_amount')->default(0)->after('admin_fee');
            $table->index(['type', 'status']);
        });

        $now = CarbonImmutable::now('UTC');
        DB::table('payments')
            ->select(['id', 'amount', 'payment_method', 'status', 'is_simulated', 'paid_at', 'created_at'])
            ->orderBy('id')
            ->chunkById(500, function ($payments) use ($now): void {
                foreach ($payments as $payment) {
                    $method = strtolower(trim($payment->payment_method ?: 'qris'));
                    $requiresSettlement = $payment->status === 'paid'
                        && ! (bool) $payment->is_simulated
                        && (int) round((float) $payment->amount) > 0
                        && str_starts_with($method, 'qris');

                    if (! $requiresSettlement) {
                        continue;
                    }

                    $paidAt = CarbonImmutable::parse($payment->paid_at ?: $payment->created_at)
                        ->setTimezone('Asia/Jakarta');
                    $dueAt = $paidAt->addDay()->startOfDay()->setHour(12)->utc();
                    $settled = $dueAt->lessThanOrEqualTo($now);

                    DB::table('payments')->where('id', $payment->id)->update([
                        'settlement_status' => $settled ? 'settled' : 'pending',
                        'settlement_due_at' => $dueAt,
                        'settled_at' => $settled ? $dueAt : null,
                    ]);
                }
            });

        DB::table('withdrawals')->update([
            'type' => 'manual',
            'admin_fee' => 0,
            'net_amount' => DB::raw('amount'),
        ]);
    }

    public function down(): void
    {
        Schema::table('withdrawals', function (Blueprint $table) {
            $table->dropIndex(['type', 'status']);
            $table->dropColumn(['type', 'admin_fee', 'net_amount']);
        });

        Schema::table('payments', function (Blueprint $table) {
            $table->dropIndex('payments_settlement_due_idx');
            $table->dropColumn(['settlement_status', 'settlement_due_at', 'settled_at']);
        });
    }
};
