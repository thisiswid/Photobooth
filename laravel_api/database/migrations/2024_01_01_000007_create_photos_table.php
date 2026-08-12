<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('photos', function (Blueprint $table) {
            $table->id();
            $table->foreignId('session_id')->constrained('photo_sessions')->cascadeOnDelete();
            $table->string('file_path');
            $table->string('thumbnail_path')->nullable();
            $table->enum('photo_type', ['individual', 'strip', 'gif'])->default('individual');
            $table->unsignedBigInteger('file_size')->nullable();
            $table->string('mime_type')->default('image/jpeg');
            $table->timestamp('captured_at')->nullable();
            $table->timestamp('created_at')->useCurrent();

            $table->index(['session_id', 'photo_type']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('photos');
    }
};
