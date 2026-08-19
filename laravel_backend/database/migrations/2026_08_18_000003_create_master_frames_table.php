<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('master_frames', function (Blueprint $table) {
            $table->id();
            $table->string('name');
            $table->string('category')->default('General'); // General, Coffee & Cafe, Vintage, Wedding, Birthday, Holiday
            $table->string('layout_type')->default('single'); // single, double_6, double_8
            $table->integer('pose_count')->default(4);
            $table->string('asset_url')->nullable();
            $table->json('layout_config')->nullable();
            $table->text('description')->nullable();
            $table->boolean('is_active')->default(true);
            $table->integer('usage_count')->default(0);
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('master_frames');
    }
};
