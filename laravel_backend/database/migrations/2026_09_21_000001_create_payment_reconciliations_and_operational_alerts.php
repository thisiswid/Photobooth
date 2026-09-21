<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('payments', function (Blueprint $table) {
            $table->string('gateway_status')->nullable()->after('status');
            $table->string('reconciliation_status')->nullable()->after('gateway_status');
            $table->text('reconciliation_message')->nullable()->after('reconciliation_status');
            $table->timestamp('last_gateway_check_at')->nullable()->after('reconciliation_message');
            $table->index(['reconciliation_status', 'last_gateway_check_at'], 'payments_reconciliation_check_index');
        });

        Schema::create('payment_reconciliations', function (Blueprint $table) {
            $table->id();
            $table->foreignId('payment_id')->constrained()->cascadeOnDelete();
            $table->foreignId('cafe_id')->nullable()->constrained()->nullOnDelete();
            $table->foreignId('checked_by')->nullable()->constrained('users')->nullOnDelete();
            $table->string('source')->default('scheduled');
            $table->string('local_status_before');
            $table->string('gateway_status')->nullable();
            $table->string('result');
            $table->unsignedBigInteger('expected_amount');
            $table->unsignedBigInteger('gateway_amount')->nullable();
            $table->text('message')->nullable();
            $table->json('response_payload')->nullable();
            $table->timestamp('checked_at');
            $table->timestamps();
            $table->index(['payment_id', 'checked_at']);
            $table->index(['cafe_id', 'result']);
        });

        Schema::create('operational_alerts', function (Blueprint $table) {
            $table->id();
            $table->string('fingerprint')->unique();
            $table->foreignId('cafe_id')->nullable()->constrained()->cascadeOnDelete();
            $table->foreignId('device_id')->nullable()->constrained()->nullOnDelete();
            $table->foreignId('payment_id')->nullable()->constrained()->nullOnDelete();
            $table->foreignId('withdrawal_id')->nullable()->constrained()->nullOnDelete();
            $table->string('category');
            $table->string('severity')->default('warning');
            $table->string('title');
            $table->text('message');
            $table->string('status')->default('active');
            $table->timestamp('first_detected_at');
            $table->timestamp('last_detected_at');
            $table->timestamp('last_notified_at')->nullable();
            $table->timestamp('resolved_at')->nullable();
            $table->json('context')->nullable();
            $table->timestamps();
            $table->index(['cafe_id', 'status']);
            $table->index(['category', 'status']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('operational_alerts');
        Schema::dropIfExists('payment_reconciliations');

        Schema::table('payments', function (Blueprint $table) {
            $table->dropIndex('payments_reconciliation_check_index');
            $table->dropColumn([
                'gateway_status',
                'reconciliation_status',
                'reconciliation_message',
                'last_gateway_check_at',
            ]);
        });
    }
};
