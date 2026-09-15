<?php

namespace App\Services;

class PakasirFeeCalculator
{
    public const UPDATED_AT = '14 September 2026';

    public const QRIS_THRESHOLD = 105000;

    /**
     * Biaya MDR QRIS Pakasir dipotong dari saldo merchant, bukan ditambahkan
     * ke nominal yang dibayar pelanggan.
     */
    public static function calculate(int|float|string $amount, ?string $paymentMethod = 'qris', bool $isSimulated = false): int
    {
        $amount = max(0, (int) round((float) $amount));
        $method = strtolower(trim($paymentMethod ?: 'qris'));

        if ($isSimulated || $amount === 0 || ! str_starts_with($method, 'qris')) {
            return 0;
        }

        if ($amount > self::QRIS_THRESHOLD) {
            return (int) round($amount * 0.01);
        }

        return (int) round($amount * 0.007) + 310;
    }

    public static function netAmount(int|float|string $amount, ?string $paymentMethod = 'qris', bool $isSimulated = false): int
    {
        $grossAmount = max(0, (int) round((float) $amount));

        return max(0, $grossAmount - self::calculate($grossAmount, $paymentMethod, $isSimulated));
    }
}
