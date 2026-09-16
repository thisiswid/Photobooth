<?php

namespace App\Services;

use App\Models\Cafe;
use Carbon\CarbonImmutable;
use DateTimeInterface;

class WithdrawalPolicyService
{
    public const TYPE_MANUAL = 'manual';

    public const TYPE_AUTOMATIC = 'automatic';

    public const MANUAL_MIN_AMOUNT = 50000;

    public const MANUAL_MAX_AMOUNT = 500000;

    public const MANUAL_MAX_LAST_24_HOURS_REVENUE = 100000;

    public const AUTOMATIC_MIN_AMOUNT = 15000;

    public const TIMEZONE = 'Asia/Jakarta';

    public static function adminFee(string $type, int|float|string $amount): int
    {
        $amount = max(0, (int) round((float) $amount));

        if ($type !== self::TYPE_AUTOMATIC) {
            return 0;
        }

        if ($amount >= 10000000) {
            return 7000;
        }

        if ($amount >= 5000000) {
            return 5000;
        }

        return 3000;
    }

    public static function netAmount(string $type, int|float|string $amount): int
    {
        $amount = max(0, (int) round((float) $amount));

        return max(0, $amount - self::adminFee($type, $amount));
    }

    public static function requestError(Cafe $cafe, string $type, int $amount, DateTimeInterface|string|null $at = null): ?string
    {
        $at = self::localTime($at);

        if (! in_array($type, [self::TYPE_MANUAL, self::TYPE_AUTOMATIC], true)) {
            return 'Jenis penarikan tidak valid.';
        }

        if ($amount > $cafe->available_balance) {
            return 'Nominal penarikan melebihi saldo tersedia sebesar Rp '.number_format($cafe->available_balance, 0, ',', '.').'.';
        }

        if ($type === self::TYPE_MANUAL) {
            if (! $at->isFriday()) {
                return 'Penarikan manual hanya dapat diajukan pada hari Jumat (WIB).';
            }

            if ($amount < self::MANUAL_MIN_AMOUNT || $amount > self::MANUAL_MAX_AMOUNT) {
                return 'Penarikan manual harus antara Rp 50.000 dan Rp 500.000.';
            }

            $last24HoursRevenue = (int) $cafe->payments()
                ->where('payments.status', 'paid')
                ->where('payments.is_simulated', false)
                ->where('payments.paid_at', '>=', $at->utc()->subDay())
                ->sum('amount');

            if ($last24HoursRevenue > self::MANUAL_MAX_LAST_24_HOURS_REVENUE) {
                return 'Penarikan manual tidak tersedia karena penghasilan 24 jam terakhir melebihi Rp 100.000.';
            }

            return null;
        }

        if ($at->isSunday() || $at->hour < 9 || $at->hour >= 16) {
            return 'Penarikan otomatis hanya dapat diajukan Senin–Sabtu pukul 09.00–16.00 WIB.';
        }

        if ($amount < self::AUTOMATIC_MIN_AMOUNT) {
            return 'Minimal penarikan otomatis adalah Rp 15.000.';
        }

        return null;
    }

    public static function manualProcessingError(DateTimeInterface|string|null $at = null): ?string
    {
        $at = self::localTime($at);

        if (! $at->isSaturday() || $at->hour < 9 || $at->hour >= 12) {
            return 'Penarikan manual hanya dapat diproses hari Sabtu pukul 09.00–12.00 WIB.';
        }

        return null;
    }

    private static function localTime(DateTimeInterface|string|null $at): CarbonImmutable
    {
        return $at
            ? CarbonImmutable::parse($at)->setTimezone(self::TIMEZONE)
            : CarbonImmutable::now(self::TIMEZONE);
    }
}
