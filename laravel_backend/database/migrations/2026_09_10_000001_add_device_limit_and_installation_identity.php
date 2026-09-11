<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('cafes', function (Blueprint $table) {
            $table->unsignedInteger('device_limit')->default(1)->after('subscription_end_at');
        });

        Schema::table('devices', function (Blueprint $table) {
            $table->uuid('installation_id')->nullable()->unique()->after('device_key');
            $table->dateTime('activated_at')->nullable()->after('installation_id');
        });
    }

    public function down(): void
    {
        Schema::table('devices', function (Blueprint $table) {
            $table->dropUnique(['installation_id']);
            $table->dropColumn(['installation_id', 'activated_at']);
        });

        Schema::table('cafes', function (Blueprint $table) {
            $table->dropColumn('device_limit');
        });
    }
};
