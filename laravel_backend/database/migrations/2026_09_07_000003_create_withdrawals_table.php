<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('withdrawals', function (Blueprint $table) {
            $table->id();
            $table->string('reference_no')->unique()->comment('No referensi penarikan, misal: WD-20260907-001');
            $table->foreignId('cafe_id')->constrained('cafes')->cascadeOnDelete();
            $table->foreignId('user_id')->constrained('users')->cascadeOnDelete()->comment('Admin cafe yang mengajukan');
            $table->unsignedBigInteger('amount')->comment('Nominal penarikan dalam Rupiah');
            $table->string('bank_name')->comment('Bank tujuan transfer');
            $table->string('bank_account_number')->comment('Nomor rekening tujuan');
            $table->string('bank_account_holder')->comment('Nama pemilik rekening tujuan');
            $table->enum('status', ['pending', 'approved', 'rejected'])->default('pending');
            $table->string('proof_of_transfer_path')->nullable()->comment('File bukti transfer yang diunggah Super Admin');
            $table->text('notes')->nullable()->comment('Catatan transfer atau alasan penolakan');
            $table->foreignId('processed_by')->nullable()->constrained('users')->nullOnDelete()->comment('Super Admin yang memproses');
            $table->timestamp('processed_at')->nullable();
            $table->timestamps();

            $table->index(['cafe_id', 'status']);
            $table->index(['status', 'created_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('withdrawals');
    }
};
