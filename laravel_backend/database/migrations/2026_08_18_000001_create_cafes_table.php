<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('cafes', function (Blueprint $table) {
            $table->id();
            $table->string('name');
            $table->string('slug')->unique();
            $table->string('code')->unique(); // Unique identifier / license code
            $table->string('pic_name')->nullable();
            $table->string('pic_phone')->nullable();
            $table->string('pic_email')->nullable();
            $table->text('address')->nullable();
            $table->string('status')->default('active'); // 'active', 'suspended', 'inactive'
            $table->dateTime('subscription_end_at')->nullable();
            $table->decimal('revenue_share_percentage', 5, 2)->default(0.00); // e.g. 10.00%
            $table->string('logo_path')->nullable();
            $table->text('notes')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('cafes');
    }
};
