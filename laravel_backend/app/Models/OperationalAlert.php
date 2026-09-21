<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class OperationalAlert extends Model
{
    protected $fillable = [
        'fingerprint', 'cafe_id', 'device_id', 'payment_id', 'withdrawal_id',
        'category', 'severity', 'title', 'message', 'status', 'first_detected_at',
        'last_detected_at', 'last_notified_at', 'resolved_at', 'context',
    ];

    protected $casts = [
        'first_detected_at' => 'datetime',
        'last_detected_at' => 'datetime',
        'last_notified_at' => 'datetime',
        'resolved_at' => 'datetime',
        'context' => 'array',
    ];

    public function cafe(): BelongsTo
    {
        return $this->belongsTo(Cafe::class);
    }

    public function device(): BelongsTo
    {
        return $this->belongsTo(Device::class);
    }

    public function payment(): BelongsTo
    {
        return $this->belongsTo(Payment::class);
    }

    public function withdrawal(): BelongsTo
    {
        return $this->belongsTo(Withdrawal::class);
    }
}
