<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->foreignId('cafe_id')->nullable()->after('id')->constrained('cafes')->nullOnDelete();
        });

        Schema::table('events', function (Blueprint $table) {
            $table->foreignId('cafe_id')->nullable()->after('id')->constrained('cafes')->cascadeOnDelete();
        });

        Schema::table('devices', function (Blueprint $table) {
            $table->foreignId('cafe_id')->nullable()->after('id')->constrained('cafes')->nullOnDelete();
            $table->string('device_key')->nullable()->unique()->after('name');
            $table->string('ip_address')->nullable()->after('platform');
            $table->timestamp('last_seen_at')->nullable()->after('status');
        });

        Schema::table('photo_sessions', function (Blueprint $table) {
            $table->foreignId('cafe_id')->nullable()->after('id')->constrained('cafes')->nullOnDelete();
        });

        Schema::table('error_logs', function (Blueprint $table) {
            $table->foreignId('cafe_id')->nullable()->after('id')->constrained('cafes')->nullOnDelete();
        });
    }

    public function down(): void
    {
        Schema::table('error_logs', function (Blueprint $table) {
            $table->dropForeign(['cafe_id']);
            $table->dropColumn('cafe_id');
        });

        Schema::table('photo_sessions', function (Blueprint $table) {
            $table->dropForeign(['cafe_id']);
            $table->dropColumn('cafe_id');
        });

        Schema::table('devices', function (Blueprint $table) {
            $table->dropForeign(['cafe_id']);
            $table->dropColumn(['cafe_id', 'device_key', 'ip_address', 'last_seen_at']);
        });

        Schema::table('events', function (Blueprint $table) {
            $table->dropForeign(['cafe_id']);
            $table->dropColumn('cafe_id');
        });

        Schema::table('users', function (Blueprint $table) {
            $table->dropForeign(['cafe_id']);
            $table->dropColumn('cafe_id');
        });
    }
};
