<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('results', function (Blueprint $table) {
            $table->id();
            $table->foreignId('session_id')->constrained('photo_sessions')->cascadeOnDelete();
            $table->string('final_url')->nullable();
            $table->string('gif_url')->nullable();
            $table->string('qr_token')->unique()->nullable();
            $table->timestamp('expires_at')->nullable();
            $table->timestamps();

            $table->index('qr_token');
            $table->index('expires_at');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('results');
    }
};
