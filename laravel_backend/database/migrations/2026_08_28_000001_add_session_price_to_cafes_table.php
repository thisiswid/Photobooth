<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('cafes', function (Blueprint $table) {
            if (!Schema::hasColumn('cafes', 'session_price')) {
                $table->unsignedInteger('session_price')->default(25000)->after('revenue_share_percentage');
            }
        });
    }

    public function down(): void
    {
        Schema::table('cafes', function (Blueprint $table) {
            if (Schema::hasColumn('cafes', 'session_price')) {
                $table->dropColumn('session_price');
            }
        });
    }
};
