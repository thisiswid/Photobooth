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
            $table->string('session_code', 8)->unique();
            $table->enum('payment_status', ['pending', 'paid', 'failed'])->default('pending');
            $table->foreignId('package_id')->nullable()->constrained('packages')->nullOnDelete();
            $table->foreignId('layout_id')->nullable()->constrained('layouts')->nullOnDelete();
            $table->foreignId('frame_id')->nullable()->constrained('frames')->nullOnDelete();
            $table->string('selected_filter')->nullable();
            $table->json('selected_sticker_ids')->nullable();
            $table->string('email')->nullable();
            $table->timestamp('started_at')->nullable();
            $table->timestamp('expired_at')->nullable();
            $table->timestamp('completed_at')->nullable();
            $table->unsignedTinyInteger('total_photos')->default(0);
            $table->string('strip_path')->nullable();
            $table->string('gif_path')->nullable();
            $table->timestamps();

            $table->index('session_code');
            $table->index('expired_at');
            $table->index('payment_status');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('photo_sessions');
    }
};
