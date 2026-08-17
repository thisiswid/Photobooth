<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class ErrorLog extends Model
{
    protected $fillable = [
        'device_id',
        'event_id',
        'category',
        'level',
        'title',
        'message',
        'context',
        'stack_trace',
        'ip_address',
    ];

    protected $casts = [
        'context' => 'array',
    ];

    public function event(): BelongsTo
    {
        return $this->belongsTo(Event::class);
    }
}
