<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('cafes', function (Blueprint $table) {
            $table->string('bank_name')->nullable()->after('notes')->comment('Nama Bank Penerima (misal: BCA, Mandiri, BRI, BNI)');
            $table->string('bank_account_number')->nullable()->after('bank_name')->comment('Nomor Rekening Penerima');
            $table->string('bank_account_holder')->nullable()->after('bank_account_number')->comment('Nama Pemilik Rekening');
        });
    }

    public function down(): void
    {
        Schema::table('cafes', function (Blueprint $table) {
            $table->dropColumn(['bank_name', 'bank_account_number', 'bank_account_holder']);
        });
    }
};
