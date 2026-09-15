<?php

namespace App\Models;

use App\Services\PakasirFeeCalculator;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasOne;

class Payment extends Model
{
    protected $fillable = [
        'session_id', 'voucher_id', 'xendit_payment_id', 'original_amount',
        'discount_amount', 'amount', 'provider_fee', 'net_amount', 'payment_method',
        'status', 'paid_at', 'is_simulated',
    ];

    protected $casts = [
        'paid_at' => 'datetime',
        'original_amount' => 'decimal:2',
        'discount_amount' => 'decimal:2',
        'amount' => 'decimal:2',
        'provider_fee' => 'decimal:2',
        'net_amount' => 'decimal:2',
        'is_simulated' => 'boolean',
    ];

    protected static function booted(): void
    {
        static::saving(function (Payment $payment): void {
            if ($payment->exists && ! $payment->isDirty(['amount', 'payment_method', 'is_simulated'])) {
                return;
            }

            $payment->payment_method = $payment->payment_method ?: 'qris';
            $payment->provider_fee = PakasirFeeCalculator::calculate(
                $payment->amount ?? 0,
                $payment->payment_method,
                (bool) $payment->is_simulated,
            );
            $payment->net_amount = PakasirFeeCalculator::netAmount(
                $payment->amount ?? 0,
                $payment->payment_method,
                (bool) $payment->is_simulated,
            );
        });
    }

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
