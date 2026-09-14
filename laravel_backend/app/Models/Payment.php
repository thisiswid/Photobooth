<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasOne;

class Payment extends Model
{
    protected $fillable = [
        'session_id', 'voucher_id', 'xendit_payment_id', 'original_amount',
        'discount_amount', 'amount', 'payment_method', 'status', 'paid_at', 'is_simulated',
    ];

    protected $casts = [
        'paid_at' => 'datetime',
        'original_amount' => 'decimal:2',
        'discount_amount' => 'decimal:2',
        'amount' => 'decimal:2',
        'is_simulated' => 'boolean',
    ];

    public function session(): BelongsTo
    {
        return $this->belongsTo(Session::class);
    }

    public function voucher(): BelongsTo
    {
        return $this->belongsTo(Voucher::class);
    }

    public function voucherRedemption(): HasOne
    {
        return $this->hasOne(VoucherRedemption::class);
    }
}
