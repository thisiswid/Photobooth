<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Photo extends Model
{
    public $timestamps = false;

    protected $fillable = [
        'session_id', 'file_path', 'thumbnail_path',
        'photo_type', 'file_size', 'mime_type', 'captured_at',
    ];

    protected $casts = [
        'file_size' => 'integer',
        'captured_at' => 'datetime',
        'created_at' => 'datetime',
    ];

    public function session(): BelongsTo
    {
        return $this->belongsTo(PhotoSession::class, 'session_id');
    }

    public function scopeByType($query, string $type)
    {
        return $query->where('photo_type', $type);
    }

    public function getFullUrlAttribute(): string
    {
        return app(\App\Services\StorageService::class)->url($this->file_path);
    }
}
