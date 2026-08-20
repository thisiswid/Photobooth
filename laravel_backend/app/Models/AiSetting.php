<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class AiSetting extends Model
{
    protected $fillable = [
        'is_enabled',
        'provider',
        'api_key',
        'model',
        'enable_frame_detection',
        'enable_auto_punch',
        'enable_photo_enhancer',
        'max_tokens',
        'temperature',
        'notes',
    ];

    protected $casts = [
        'is_enabled'             => 'boolean',
        'enable_frame_detection' => 'boolean',
        'enable_auto_punch'      => 'boolean',
        'enable_photo_enhancer'  => 'boolean',
        'max_tokens'             => 'integer',
        'temperature'            => 'decimal:2',
    ];

    /**
     * Get or create global singleton instance of AiSetting.
     */
    public static function getGlobal(): self
    {
        return static::firstOrCreate(
            ['id' => 1],
            [
                'is_enabled'             => true,
                'provider'               => 'gemini',
                'api_key'                => null, // Falls back to GEMINI_API_KEY in .env
                'model'                  => 'gemini-1.5-flash',
                'enable_frame_detection' => true,
                'enable_auto_punch'      => true,
                'enable_photo_enhancer'  => false,
                'max_tokens'             => 2048,
                'temperature'            => 0.20,
                'notes'                  => 'Default Global AI Configuration',
            ]
        );
    }

    /**
     * Helper to check if AI features are enabled globally and for a specific cafe.
     */
    public static function isAiAvailable(?int $cafeId = null): bool
    {
        $global = static::getGlobal();
        if (!$global->is_enabled) {
            return false;
        }

        if ($cafeId) {
            $cafe = Cafe::find($cafeId);
            if ($cafe && !$cafe->is_ai_enabled) {
                return false;
            }
        }

        return true;
    }
}
