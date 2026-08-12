<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('payments', function (Blueprint $table) {
            $table->id();
            $table->foreignId('session_id')->constrained('photo_sessions')->cascadeOnDelete();
            $table->string('xendit_payment_id')->nullable();
            $table->decimal('amount', 12, 2)->default(0);
            $table->string('status')->default('pending'); // pending, paid, failed
            $table->timestamp('paid_at')->nullable();
            $table->timestamps();

            $table->index('status');
            $table->index('xendit_payment_id');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('payments');
    }
};
