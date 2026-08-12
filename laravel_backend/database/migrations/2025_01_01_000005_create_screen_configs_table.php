<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('screen_configs', function (Blueprint $table) {
            $table->id();
            $table->foreignId('event_id')->nullable()->constrained('events')->nullOnDelete();
            $table->string('screen_type'); // welcome, tutorial
            $table->string('status')->default('draft'); // draft, preview, published, active
            $table->string('title')->nullable();
            $table->text('description')->nullable();
            $table->string('background_url')->nullable();
            $table->string('button_text')->nullable();
            $table->integer('version')->default(1);
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('screen_configs');
    }
};
