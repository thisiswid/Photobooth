<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('photo_sessions', function (Blueprint $table) {
            $table->id();
            $table->foreignId('event_id')->nullable()->constrained('events')->nullOnDelete();
            $table->foreignId('frame_id')->nullable()->constrained('frames')->nullOnDelete();
            $table->foreignId('filter_id')->nullable()->constrained('filters')->nullOnDelete();
            $table->foreignId('device_id')->nullable()->constrained('devices')->nullOnDelete();
            $table->string('status')->default('pending'); // pending, active, processing, result_ready, finished, timeout
            $table->string('selected_filter')->nullable();
            $table->integer('retake_count')->default(0);
            $table->string('email')->nullable();
            $table->timestamp('started_at')->nullable();
            $table->timestamp('expires_at')->nullable();
            $table->timestamp('finished_at')->nullable();
            $table->timestamps();

            $table->index('status');
            $table->index('expires_at');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('photo_sessions');
    }
};
