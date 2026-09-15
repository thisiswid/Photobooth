@once
    <style>
        .stb-fee-guide {
            color: #4b5563;
            font-size: .82rem;
        }

        .stb-fee-guide__summary,
        .stb-fee-guide__va {
            display: grid;
            grid-template-columns: repeat(3, minmax(0, 1fr));
            gap: .75rem;
        }

        .stb-fee-guide__item {
            padding: .9rem 1rem;
            border: 1px solid #e5e7eb;
            border-radius: .75rem;
            background: #fff;
        }

        .stb-fee-guide__item--primary {
            border-color: #fcd34d;
            background: #fffbeb;
        }

        .stb-fee-guide__label {
            display: block;
            margin-bottom: .2rem;
            color: #6b7280;
            font-size: .7rem;
            font-weight: 700;
            letter-spacing: .035em;
            text-transform: uppercase;
        }

        .stb-fee-guide__value {
            color: #111827;
            font-size: .9rem;
            font-weight: 700;
        }

        .stb-fee-guide__note {
            margin: .85rem 0 0;
            line-height: 1.55;
        }

        .stb-fee-guide__va-title {
            margin: 1rem 0 .65rem;
            color: #111827;
            font-weight: 700;
        }

        .stb-fee-guide__va {
            grid-template-columns: repeat(4, minmax(0, 1fr));
        }

        .stb-fee-guide__va-row {
            display: flex;
            justify-content: space-between;
            gap: .75rem;
            padding: .65rem .75rem;
            border: 1px solid #e5e7eb;
            border-radius: .6rem;
        }

        .stb-fee-guide__va-row strong {
            color: #111827;
            white-space: nowrap;
        }

        .dark .stb-fee-guide {
            color: #d1d5db;
        }

        .dark .stb-fee-guide__item,
        .dark .stb-fee-guide__va-row {
            border-color: #374151;
            background: #111827;
        }

        .dark .stb-fee-guide__item--primary {
            border-color: #92400e;
            background: rgba(120, 53, 15, .2);
        }

        .dark .stb-fee-guide__value,
        .dark .stb-fee-guide__va-title,
        .dark .stb-fee-guide__va-row strong {
            color: #f9fafb;
        }

        .dark .stb-fee-guide__label {
            color: #9ca3af;
        }

        @media (max-width: 900px) {
            .stb-fee-guide__summary {
                grid-template-columns: 1fr;
            }

            .stb-fee-guide__va {
                grid-template-columns: repeat(2, minmax(0, 1fr));
            }
        }

        @media (max-width: 520px) {
            .stb-fee-guide__va {
                grid-template-columns: 1fr;
            }
        }
    </style>
@endonce

<x-filament-widgets::widget>
    <x-filament::section
        heading="Biaya Layanan Pakasir"
        description="Diperbarui {{ \App\Services\PakasirFeeCalculator::UPDATED_AT }}"
        icon="heroicon-o-receipt-percent"
        icon-color="warning"
        collapsible
        collapsed
        persist-collapsed
        collapse-id="pakasir-payment-fees"
    >
        <div class="stb-fee-guide">
            <div class="stb-fee-guide__summary">
                <div class="stb-fee-guide__item stb-fee-guide__item--primary">
                    <span class="stb-fee-guide__label">QRIS sampai Rp 105.000</span>
                    <span class="stb-fee-guide__value">0,7% + Rp 310</span>
                </div>
                <div class="stb-fee-guide__item">
                    <span class="stb-fee-guide__label">QRIS di atas Rp 105.000</span>
                    <span class="stb-fee-guide__value">1% tanpa biaya tetap</span>
                </div>
                <div class="stb-fee-guide__item">
                    <span class="stb-fee-guide__label">Pencatatan dashboard</span>
                    <span class="stb-fee-guide__value">Bruto &minus; biaya = neto cafe</span>
                </div>
            </div>

            <p class="stb-fee-guide__note">
                Biaya QRIS dipotong dari saldo merchant. Transaksi simulasi dan pembayaran penuh menggunakan voucher tidak dikenakan biaya Pakasir.
            </p>

            <p class="stb-fee-guide__va-title">Referensi biaya Virtual Account</p>
            <div class="stb-fee-guide__va">
                @foreach ([
                    'BRI' => 3500,
                    'BNI' => 3500,
                    'BNC' => 3500,
                    'CIMB Niaga' => 3500,
                    'Maybank' => 3500,
                    'Permata' => 3500,
                    'Artha Graha' => 2000,
                    'Sampoerna' => 2000,
                ] as $bank => $fee)
                    <div class="stb-fee-guide__va-row">
                        <span>{{ $bank }}</span>
                        <strong>Rp {{ number_format($fee, 0, ',', '.') }}</strong>
                    </div>
                @endforeach
            </div>
        </div>
    </x-filament::section>
</x-filament-widgets::widget>
