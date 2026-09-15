<?php

namespace App\Services;

use App\Models\Cafe;
use App\Models\Device;
use App\Models\Payment;
use App\Models\Session;
use App\Models\Voucher;
use App\Models\VoucherRedemption;
use Illuminate\Validation\ValidationException;

class VoucherService
{
    public static function quote(
        Cafe $cafe,
        string $code,
        int $originalAmount,
        ?int $eventId,
        string $installationId,
        bool $lock = false,
    ): array {
        $query = Voucher::query()
            ->where('cafe_id', $cafe->id)
            ->whereRaw('UPPER(code) = ?', [strtoupper(trim($code))]);

        if ($lock) {
            $query->lockForUpdate();
        }

        $voucher = $query->first();
        self::ensureValid($voucher, $originalAmount, $eventId, $installationId);

        $discount = match ($voucher->type) {
            'full' => $originalAmount,
            'fixed' => min($originalAmount, (int) $voucher->value),
            'percentage' => min(
                $originalAmount,
                $voucher->max_discount
                    ? min((int) floor($originalAmount * $voucher->value / 100), (int) $voucher->max_discount)
                    : (int) floor($originalAmount * $voucher->value / 100),
            ),
            default => throw ValidationException::withMessages(['voucher_code' => 'Tipe voucher tidak valid.']),
        };

        return [
            'voucher' => $voucher,
            'original_amount' => $originalAmount,
            'discount_amount' => max(0, $discount),
            'final_amount' => max(0, $originalAmount - $discount),
        ];
    }

    public static function reserve(array $quote, Device $device, Session $session, Payment $payment, string $installationId): VoucherRedemption
    {
        /** @var Voucher $voucher */
        $voucher = $quote['voucher'];

        $redemption = VoucherRedemption::create([
            'voucher_id' => $voucher->id,
            'cafe_id' => $voucher->cafe_id,
            'device_id' => $device->id,
            'session_id' => $session->id,
            'payment_id' => $payment->id,
            'installation_id' => $installationId,
            'discount_amount' => $quote['discount_amount'],
            'status' => $quote['final_amount'] === 0 ? 'used' : 'reserved',
            'reserved_until' => $quote['final_amount'] === 0 ? null : now()->addMinutes(20),
            'used_at' => $quote['final_amount'] === 0 ? now() : null,
        ]);

        if ($quote['final_amount'] === 0) {
            $voucher->increment('used_count');
        }

        return $redemption;
    }

    public static function consume(Payment $payment): void
    {
        $redemption = VoucherRedemption::where('payment_id', $payment->id)->lockForUpdate()->first();
        if (! $redemption || $redemption->status === 'used') {
            return;
        }

        $voucher = Voucher::whereKey($redemption->voucher_id)->lockForUpdate()->first();
        $redemption->update(['status' => 'used', 'used_at' => now(), 'reserved_until' => null]);
        $voucher?->increment('used_count');
    }

    public static function release(Payment $payment): void
    {
        VoucherRedemption::where('payment_id', $payment->id)
            ->where('status', 'reserved')
            ->update(['status' => 'released', 'reserved_until' => null]);
    }

    private static function ensureValid(?Voucher $voucher, int $amount, ?int $eventId, string $installationId): void
    {
        if (! $voucher) {
            throw ValidationException::withMessages(['voucher_code' => 'Kode voucher tidak ditemukan untuk cafe ini.']);
        }
        if (! $voucher->is_active) {
            throw ValidationException::withMessages(['voucher_code' => 'Voucher sedang tidak aktif.']);
        }
        if ($voucher->starts_at && $voucher->starts_at->isFuture()) {
            throw ValidationException::withMessages(['voucher_code' => 'Voucher belum mulai berlaku.']);
        }
        if ($voucher->expires_at && $voucher->expires_at->isPast()) {
            throw ValidationException::withMessages(['voucher_code' => 'Voucher sudah kedaluwarsa.']);
        }
        if ($voucher->event_id && (int) $voucher->event_id !== (int) $eventId) {
            throw ValidationException::withMessages(['voucher_code' => 'Voucher tidak berlaku untuk event ini.']);
        }
        if ($amount < $voucher->minimum_purchase) {
            throw ValidationException::withMessages(['voucher_code' => 'Minimum transaksi voucher belum terpenuhi.']);
        }

        $voucher->redemptions()
            ->where('status', 'reserved')
            ->where('reserved_until', '<=', now())
            ->update(['status' => 'released', 'reserved_until' => null]);

        $activeReservations = $voucher->redemptions()
            ->where('status', 'reserved')
            ->where('reserved_until', '>', now())
            ->count();
        if ($voucher->quota !== null && ($voucher->used_count + $activeReservations) >= $voucher->quota) {
            throw ValidationException::withMessages(['voucher_code' => 'Kuota voucher sudah habis.']);
        }

        if ($voucher->per_device_limit !== null) {
            $deviceUsage = $voucher->redemptions()
                ->where('installation_id', $installationId)
                ->where(function ($query) {
                    $query->where('status', 'used')
                        ->orWhere(fn ($reserved) => $reserved->where('status', 'reserved')->where('reserved_until', '>', now()));
                })
                ->count();
            if ($deviceUsage >= $voucher->per_device_limit) {
                throw ValidationException::withMessages(['voucher_code' => 'Batas penggunaan voucher pada perangkat ini sudah tercapai.']);
            }
        }
    }
}
