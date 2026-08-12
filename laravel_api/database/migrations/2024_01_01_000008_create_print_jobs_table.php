<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('print_jobs', function (Blueprint $table) {
            $table->id();
            $table->foreignId('session_id')->constrained('photo_sessions')->cascadeOnDelete();
            $table->enum('status', ['pending', 'preparing', 'printing', 'completed', 'error'])
                  ->default('pending');
            $table->unsignedTinyInteger('copies')->default(1);
            $table->string('printer_name')->nullable();
            $table->timestamp('started_at')->nullable();
            $table->timestamp('completed_at')->nullable();
            $table->text('error_message')->nullable();
            $table->timestamps();

            $table->index(['session_id', 'status']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('print_jobs');
    }
};
