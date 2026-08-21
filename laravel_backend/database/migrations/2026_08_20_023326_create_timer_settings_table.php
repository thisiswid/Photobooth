<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::create('timer_settings', function (Blueprint $table) {
            $table->id();
            $table->foreignId('cafe_id')->nullable()->constrained('cafes')->cascadeOnDelete();
            $table->foreignId('event_id')->nullable()->constrained('events')->nullOnDelete();
            $table->string('name')->default('Standar Timer');
            $table->unsignedInteger('camera_countdown_seconds')->default(5)->comment('Hitung mundur jepret kamera per pose');
            $table->unsignedInteger('session_timeout_seconds')->default(300)->comment('Batas total waktu sesi (detik)');
            $table->unsignedInteger('payment_timeout_seconds')->default(120)->comment('Batas waktu pembayaran QRIS (detik)');
            $table->unsignedInteger('result_screen_timeout_seconds')->default(60)->comment('Waktu auto reset di layar hasil (detik)');
            $table->unsignedInteger('retake_timeout_seconds')->default(60)->comment('Batas waktu pemilihan retake (detik)');
            $table->boolean('is_active')->default(true);
            $table->timestamps();
        });

        $now = now();
        $cafeId = \Illuminate\Support\Facades\DB::table('cafes')->value('id');
        $eventId = \Illuminate\Support\Facades\DB::table('events')->value('id');

        \Illuminate\Support\Facades\DB::table('timer_settings')->insert([
            [
                'cafe_id'                       => null,
                'event_id'                      => null,
                'name'                          => 'Standar Timer Global (Default)',
                'camera_countdown_seconds'      => 5,
                'session_timeout_seconds'       => 300,
                'payment_timeout_seconds'       => 120,
                'result_screen_timeout_seconds' => 60,
                'retake_timeout_seconds'        => 60,
                'is_active'                     => true,
                'created_at'                    => $now,
                'updated_at'                    => $now,
            ],
            [
                'cafe_id'                       => $cafeId ?? 1,
                'event_id'                      => $eventId ?? 1,
                'name'                          => 'Timer Standar Cafe',
                'camera_countdown_seconds'      => 5,
                'session_timeout_seconds'       => 300,
                'payment_timeout_seconds'       => 120,
                'result_screen_timeout_seconds' => 60,
                'retake_timeout_seconds'        => 60,
                'is_active'                     => true,
                'created_at'                    => $now,
                'updated_at'                    => $now,
            ],
        ]);
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('timer_settings');
    }
};
