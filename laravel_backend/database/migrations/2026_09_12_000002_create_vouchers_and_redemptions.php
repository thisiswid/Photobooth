<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('vouchers', function (Blueprint $table) {
            $table->id();
            $table->foreignId('cafe_id')->constrained('cafes')->cascadeOnDelete();
            $table->foreignId('event_id')->nullable()->constrained('events')->nullOnDelete();
            $table->string('name');
            $table->string('code')->unique();
            $table->string('type'); // full, fixed, percentage
            $table->unsignedBigInteger('value')->default(0);
            $table->unsignedBigInteger('max_discount')->nullable();
            $table->unsignedBigInteger('minimum_purchase')->default(0);
            $table->unsignedInteger('quota')->nullable();
            $table->unsignedInteger('used_count')->default(0);
            $table->unsignedInteger('per_device_limit')->nullable();
            $table->timestamp('starts_at')->nullable();
            $table->timestamp('expires_at')->nullable();
            $table->boolean('is_active')->default(true);
            $table->text('notes')->nullable();
            $table->timestamps();

            $table->index(['cafe_id', 'is_active']);
            $table->index(['event_id', 'is_active']);
        });

        Schema::table('payments', function (Blueprint $table) {
            $table->foreignId('voucher_id')->nullable()->after('session_id')->constrained('vouchers')->nullOnDelete();
            $table->decimal('original_amount', 12, 2)->default(0)->after('voucher_id');
            $table->decimal('discount_amount', 12, 2)->default(0)->after('original_amount');
            $table->string('payment_method')->default('qris')->after('amount');
        });

        DB::table('payments')->update(['original_amount' => DB::raw('amount')]);

        Schema::create('voucher_redemptions', function (Blueprint $table) {
            $table->id();
            $table->foreignId('voucher_id')->constrained('vouchers')->cascadeOnDelete();
            $table->foreignId('cafe_id')->constrained('cafes')->cascadeOnDelete();
            $table->foreignId('device_id')->nullable()->constrained('devices')->nullOnDelete();
            $table->foreignId('session_id')->nullable()->constrained('photo_sessions')->nullOnDelete();
            $table->foreignId('payment_id')->nullable()->unique()->constrained('payments')->nullOnDelete();
            $table->uuid('installation_id');
            $table->unsignedBigInteger('discount_amount');
            $table->string('status')->default('reserved'); // reserved, used, released
            $table->timestamp('reserved_until')->nullable();
            $table->timestamp('used_at')->nullable();
            $table->timestamps();

            $table->index(['voucher_id', 'status']);
            $table->index(['voucher_id', 'installation_id', 'status'], 'voucher_installation_status_idx');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('voucher_redemptions');

        Schema::table('payments', function (Blueprint $table) {
            $table->dropConstrainedForeignId('voucher_id');
            $table->dropColumn(['original_amount', 'discount_amount', 'payment_method']);
        });

        Schema::dropIfExists('vouchers');
    }
};
