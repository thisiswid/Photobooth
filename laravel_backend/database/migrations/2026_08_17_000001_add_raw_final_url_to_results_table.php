<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('results', function (Blueprint $table) {
            if (!Schema::hasColumn('results', 'raw_final_url')) {
                $table->string('raw_final_url')->nullable()->after('final_url');
            }
        });
    }

    public function down(): void
    {
        Schema::table('results', function (Blueprint $table) {
            if (Schema::hasColumn('results', 'raw_final_url')) {
                $table->dropColumn('raw_final_url');
            }
        });
    }
};
