<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class PrintJob extends Model
{
    protected $fillable = [
        'session_id', 'status', 'copies', 'printer_name',
        'started_at', 'completed_at', 'error_message',
    ];

    protected $casts = [
        'copies' => 'integer',
        'started_at' => 'datetime',
        'completed_at' => 'datetime',
    ];

    public function session(): BelongsTo
    {
        return $this->belongsTo(PhotoSession::class, 'session_id');
    }
}
