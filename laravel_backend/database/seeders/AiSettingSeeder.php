<?php

namespace Database\Seeders;

use App\Models\AiSetting;
use Illuminate\Database\Seeder;

class AiSettingSeeder extends Seeder
{
    public function run(): void
    {
        AiSetting::updateOrCreate(
            ['id' => 1],
            [
                'is_enabled'             => true,
                'provider'               => 'gemini',
                'api_key'                => null,
                'model'                  => 'gemini-1.5-flash',
                'enable_frame_detection' => true,
                'enable_auto_punch'      => true,
                'enable_photo_enhancer'  => false,
                'max_tokens'             => 2048,
                'temperature'            => 0.20,
                'notes'                  => 'Konfigurasi Utama AI Platform SnapTechBooth',
            ]
        );
    }
}
