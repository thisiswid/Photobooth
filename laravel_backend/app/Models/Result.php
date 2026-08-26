<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Facades\Storage;

class Result extends Model
{
    protected $fillable = ['session_id', 'final_url', 'raw_final_url', 'gif_url', 'video_url', 'qr_token', 'expires_at'];

    protected $casts = ['expires_at' => 'datetime'];

    protected static function booted(): void
    {
        static::deleting(function (Result $result) {
            $files = array_filter([
                $result->final_url,
                $result->raw_final_url,
                $result->gif_url,
                $result->video_url,
            ]);

            foreach ($files as $file) {
                if (Storage::disk('public')->exists($file)) {
                    Storage::disk('public')->delete($file);
                }
            }
        });
    }

    public function session(): BelongsTo
    {
        return $this->belongsTo(Session::class);
    }
}
