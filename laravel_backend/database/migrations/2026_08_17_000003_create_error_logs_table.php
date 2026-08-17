<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('error_logs', function (Blueprint $table) {
            $table->id();
            $table->string('device_id')->nullable();
            $table->foreignId('event_id')->nullable()->constrained('events')->nullOnDelete();
            $table->string('category')->default('system'); // network, payment, camera, api_fetch, system, hardware
            $table->string('level')->default('error');      // info, warning, error, critical
            $table->string('title');
            $table->text('message');
            $table->json('context')->nullable();
            $table->longText('stack_trace')->nullable();
            $table->string('ip_address')->nullable();
            $table->timestamps();

            $table->index('category');
            $table->index('level');
            $table->index('created_at');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('error_logs');
    }
};
