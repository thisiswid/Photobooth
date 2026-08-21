<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;
use App\Models\Cafe;

return new class extends Migration
{
    public function up(): void
    {
        $defaultCafeId = Cafe::first()?->id ?? 1;

        DB::table('events')
            ->whereNull('cafe_id')
            ->update(['cafe_id' => $defaultCafeId]);

        DB::table('error_logs')
            ->whereNull('cafe_id')
            ->update(['cafe_id' => $defaultCafeId]);

        DB::table('devices')
            ->whereNull('cafe_id')
            ->update(['cafe_id' => $defaultCafeId]);
    }

    public function down(): void
    {
        // No reverse needed for backfill data
    }
};
