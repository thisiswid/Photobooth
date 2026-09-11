<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('cafes', function (Blueprint $table) {
            $table->boolean('payment_simulation_enabled')->default(false);
        });

        Schema::table('payments', function (Blueprint $table) {
            $table->boolean('is_simulated')->default(false)->index();
        });
    }

    public function down(): void
    {
        Schema::table('payments', function (Blueprint $table) {
            $table->dropIndex(['is_simulated']);
            $table->dropColumn('is_simulated');
        });

        Schema::table('cafes', function (Blueprint $table) {
            $table->dropColumn('payment_simulation_enabled');
        });
    }
};
