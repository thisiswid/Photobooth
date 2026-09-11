<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Payment extends Model
{
    protected $fillable = ['session_id', 'xendit_payment_id', 'amount', 'status', 'paid_at', 'is_simulated'];

    protected $casts = ['paid_at' => 'datetime', 'amount' => 'decimal:2', 'is_simulated' => 'boolean'];

    public function session(): BelongsTo
    {
        return $this->belongsTo(Session::class);
    }
}
