<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class PaymentReconciliation extends Model
{
    protected $fillable = [
        'payment_id', 'cafe_id', 'checked_by', 'source', 'local_status_before',
        'gateway_status', 'result', 'expected_amount', 'gateway_amount', 'message',
        'response_payload', 'checked_at',
    ];

    protected $casts = [
        'response_payload' => 'array',
        'checked_at' => 'datetime',
    ];

    public function payment(): BelongsTo
    {
        return $this->belongsTo(Payment::class);
    }

    public function cafe(): BelongsTo
    {
        return $this->belongsTo(Cafe::class);
    }

    public function checker(): BelongsTo
    {
        return $this->belongsTo(User::class, 'checked_by');
    }
}
