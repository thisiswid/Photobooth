<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Nilai 1 sebelumnya berasal dari default form/migration. Pada kiosk
        // bersama, itu membuat pelanggan kedua selalu dianggap sudah memakai
        // voucher meskipun kuota total masih tersedia.
        DB::table('vouchers')->where('per_device_limit', 1)->update([
            'per_device_limit' => null,
        ]);

        Schema::table('vouchers', function (Blueprint $table) {
            $table->unsignedInteger('per_device_limit')->nullable()->default(null)->change();
        });
    }

    public function down(): void
    {
        Schema::table('vouchers', function (Blueprint $table) {
            $table->unsignedInteger('per_device_limit')->nullable()->default(1)->change();
        });
    }
};
