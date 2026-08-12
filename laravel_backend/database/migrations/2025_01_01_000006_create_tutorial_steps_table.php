<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('tutorial_steps', function (Blueprint $table) {
            $table->id();
            $table->foreignId('screen_config_id')->constrained('screen_configs')->cascadeOnDelete();
            $table->integer('sort_order')->default(0);
            $table->string('title')->nullable();
            $table->text('description')->nullable();
            $table->string('image_url')->nullable();
            $table->boolean('active')->default(true);
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('tutorial_steps');
    }
};
