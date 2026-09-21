<?php

namespace App\Models;

use App\Services\PakasirFeeCalculator;
use App\Services\PakasirSettlementService;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;

class Payment extends Model
{
    protected $fillable = [
        'session_id', 'voucher_id', 'xendit_payment_id', 'original_amount',
        'discount_amount', 'amount', 'provider_fee', 'net_amount', 'payment_method',
        'settlement_status', 'settlement_due_at', 'settled_at', 'status', 'paid_at', 'is_simulated',
        'gateway_status', 'reconciliation_status', 'reconciliation_message', 'last_gateway_check_at',
    ];

    protected $casts = [
        'paid_at' => 'datetime',
        'original_amount' => 'decimal:2',
        'discount_amount' => 'decimal:2',
        'amount' => 'decimal:2',
        'provider_fee' => 'decimal:2',
        'net_amount' => 'decimal:2',
        'settlement_due_at' => 'datetime',
        'settled_at' => 'datetime',
        'is_simulated' => 'boolean',
        'last_gateway_check_at' => 'datetime',
    ];

    protected static function booted(): void
    {
        static::saving(function (Payment $payment): void {
            $financialsChanged = ! $payment->exists
                || $payment->isDirty(['amount', 'payment_method', 'is_simulated']);

            if ($financialsChanged) {
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
            }

            if (
                $payment->status === 'paid'
                && (! $payment->exists || $payment->isDirty(['status', 'amount', 'payment_method', 'is_simulated', 'paid_at']))
                && ! $payment->isDirty('settlement_status')
            ) {
                $payment->forceFill(PakasirSettlementService::attributes(
                    $payment->amount ?? 0,
                    $payment->payment_method,
                    (bool) $payment->is_simulated,
                    $payment->paid_at ?? now(),
                ));
            }
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

    public function reconciliations(): HasMany
    {
        return $this->hasMany(PaymentReconciliation::class);
    }
}
