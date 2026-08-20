<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('ai_settings', function (Blueprint ) {
            ->id();
            ->boolean('is_enabled')->default(true);
            ->string('provider')->default('gemini'); // 'gemini', 'openagentic', 'openai'
            ->text('api_key')->nullable();
            ->string('model')->default('gemini-1.5-flash');
            ->boolean('enable_frame_detection')->default(true);
            ->boolean('enable_auto_punch')->default(true);
            ->boolean('enable_photo_enhancer')->default(false);
            ->integer('max_tokens')->default(2048);
            ->decimal('temperature', 3, 2)->default(0.20);
            ->text('notes')->nullable();
            ->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('ai_settings');
    }
};
