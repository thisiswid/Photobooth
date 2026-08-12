<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Payment extends Model
{
    protected $fillable = ['session_id', 'xendit_payment_id', 'amount', 'status', 'paid_at'];

    protected $casts = ['paid_at' => 'datetime', 'amount' => 'decimal:2'];

    public function session(): BelongsTo
    {
        return $this->belongsTo(Session::class);
    }
}
