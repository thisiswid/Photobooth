<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('frames', function (Blueprint $table) {
            $table->integer('pose_count')->default(4)->after('asset_url');
            $table->json('layout_config')->nullable()->after('pose_count');
        });
    }

    public function down(): void
    {
        Schema::table('frames', function (Blueprint $table) {
            $table->dropColumn(['pose_count', 'layout_config']);
        });
    }
};
