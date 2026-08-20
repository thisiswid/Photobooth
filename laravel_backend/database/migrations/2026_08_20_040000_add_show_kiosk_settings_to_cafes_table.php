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
        Schema::table('cafes', function (Blueprint $table) {
            $table->boolean('show_kiosk_settings')
                ->default(true)
                ->after('is_ai_enabled')
                ->comment('Toggle to show/hide the hardware settings gear icon on Kiosk welcome screen');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('cafes', function (Blueprint $table) {
            $table->dropColumn('show_kiosk_settings');
        });
    }
};
