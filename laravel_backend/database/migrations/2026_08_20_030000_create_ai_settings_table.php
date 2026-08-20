<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('ai_settings', function (Blueprint $table) {
            $table->id();
            $table->boolean('is_enabled')->default(true);
            $table->string('provider')->default('gemini'); // 'gemini', 'openagentic', 'openai'
            $table->text('api_key')->nullable();
            $table->string('model')->default('gemini-1.5-flash');
            $table->boolean('enable_frame_detection')->default(true);
            $table->boolean('enable_auto_punch')->default(true);
            $table->boolean('enable_photo_enhancer')->default(false);
            $table->integer('max_tokens')->default(2048);
            $table->decimal('temperature', 3, 2)->default(0.20);
            $table->text('notes')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('ai_settings');
    }
};
