<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('filters', function (Blueprint $table) {
            $table->id();
            $table->foreignId('event_id')->nullable()->constrained('events')->nullOnDelete();
            $table->string('name');
            $table->string('thumbnail_url')->nullable();
            $table->string('parameters')->nullable();
            $table->integer('sort_order')->default(0);
            $table->boolean('active')->default(true);
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('filters');
    }
};
