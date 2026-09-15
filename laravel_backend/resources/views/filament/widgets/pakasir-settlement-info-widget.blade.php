@once
    <style>
        .stb-withdrawal-guide {
            color: #4b5563;
            font-size: .875rem;
            line-height: 1.55;
        }

        .stb-withdrawal-guide__cards {
            display: grid;
            grid-template-columns: repeat(3, minmax(0, 1fr));
            gap: 1rem;
        }

        .stb-withdrawal-card {
            min-width: 0;
            padding: 1.25rem;
            border: 1px solid #e5e7eb;
            border-radius: .875rem;
            background: #fff;
        }

        .stb-withdrawal-card--settlement {
            border-color: #fcd34d;
            background: #fffbeb;
        }

        .stb-withdrawal-card__header {
            display: flex;
            align-items: flex-start;
            gap: .75rem;
        }

        .stb-withdrawal-card__icon {
            display: grid;
            width: 2.25rem;
            height: 2.25rem;
            flex: 0 0 2.25rem;
            place-items: center;
            border-radius: .625rem;
            color: #b45309;
            background: #fef3c7;
        }

        .stb-withdrawal-card__icon--manual {
            color: #15803d;
            background: #dcfce7;
        }

        .stb-withdrawal-card__icon--automatic {
            color: #4f46e5;
            background: #eef2ff;
        }

        .stb-withdrawal-card__title {
            margin: 0;
            color: #111827;
            font-size: .95rem;
            font-weight: 700;
            line-height: 1.35;
        }

        .stb-withdrawal-card__subtitle {
            margin: .25rem 0 0;
            color: #6b7280;
            font-size: .75rem;
            line-height: 1.4;
        }

        .stb-withdrawal-card__schedule {
            margin: .3rem 0 0;
            color: #b45309;
            font-size: .72rem;
            font-weight: 700;
            letter-spacing: .035em;
            text-transform: uppercase;
        }

        .stb-withdrawal-card__body {
            margin: 1rem 0 0;
            line-height: 1.65;
        }

        .stb-withdrawal-card__badge {
            margin-left: auto;
            padding: .25rem .65rem;
            border-radius: 999px;
            color: #166534;
            background: #dcfce7;
            font-size: .7rem;
            font-weight: 700;
            white-space: nowrap;
        }

        .stb-withdrawal-list {
            display: grid;
            gap: .65rem;
            margin: 1rem 0 0;
            padding: 0;
            list-style: none;
        }

        .stb-withdrawal-list li {
            display: grid;
            grid-template-columns: .75rem minmax(0, 1fr);
            gap: .5rem;
            align-items: start;
        }

        .stb-withdrawal-list li::before {
            width: .42rem;
            height: .42rem;
            margin-top: .48rem;
            border-radius: 999px;
            background: #22c55e;
            content: '';
        }

        .stb-withdrawal-list--automatic li::before {
            background: #6366f1;
        }

        .stb-withdrawal-fees {
            margin-top: 1rem;
            overflow: hidden;
            border: 1px solid #e5e7eb;
            border-radius: .875rem;
            background: #fff;
        }

        .stb-withdrawal-fees__header {
            padding: .85rem 1.25rem;
            border-bottom: 1px solid #e5e7eb;
            color: #111827;
            background: #f9fafb;
            font-weight: 700;
        }

        .stb-withdrawal-fees__grid {
            display: grid;
            grid-template-columns: repeat(3, minmax(0, 1fr));
        }

        .stb-withdrawal-fee {
            padding: 1rem 1.25rem;
        }

        .stb-withdrawal-fee + .stb-withdrawal-fee {
            border-left: 1px solid #e5e7eb;
        }

        .stb-withdrawal-fee__range {
            margin: 0;
            color: #6b7280;
            font-size: .75rem;
        }

        .stb-withdrawal-fee__amount {
            margin: .3rem 0 0;
            color: #111827;
            font-size: 1.05rem;
            font-weight: 750;
        }

        .stb-withdrawal-guide__footer {
            display: flex;
            align-items: center;
            justify-content: space-between;
            gap: 1rem;
            margin-top: 1rem;
            padding-top: 1rem;
            border-top: 1px solid #e5e7eb;
            color: #6b7280;
            font-size: .75rem;
        }

        .stb-withdrawal-guide__footer p {
            margin: 0;
        }

        .stb-withdrawal-guide__links {
            display: flex;
            flex-wrap: wrap;
            gap: .5rem 1rem;
        }

        .stb-withdrawal-guide__links a {
            color: #b45309;
            font-weight: 700;
            text-decoration: none;
        }

        .stb-withdrawal-guide__links a:hover {
            text-decoration: underline;
        }

        .dark .stb-withdrawal-guide {
            color: #d1d5db;
        }

        .dark .stb-withdrawal-card,
        .dark .stb-withdrawal-fees {
            border-color: #374151;
            background: #111827;
        }

        .dark .stb-withdrawal-card--settlement {
            border-color: #92400e;
            background: rgba(120, 53, 15, .2);
        }

        .dark .stb-withdrawal-card__title,
        .dark .stb-withdrawal-fees__header,
        .dark .stb-withdrawal-fee__amount {
            color: #f9fafb;
        }

        .dark .stb-withdrawal-card__subtitle,
        .dark .stb-withdrawal-fee__range,
        .dark .stb-withdrawal-guide__footer {
            color: #9ca3af;
        }

        .dark .stb-withdrawal-fees__header {
            border-color: #374151;
            background: rgba(255, 255, 255, .04);
        }

        .dark .stb-withdrawal-fee + .stb-withdrawal-fee,
        .dark .stb-withdrawal-guide__footer {
            border-color: #374151;
        }

        @media (max-width: 1100px) {
            .stb-withdrawal-guide__cards {
                grid-template-columns: 1fr;
            }
        }

        @media (max-width: 700px) {
            .stb-withdrawal-fees__grid {
                grid-template-columns: 1fr;
            }

            .stb-withdrawal-fee + .stb-withdrawal-fee {
                border-top: 1px solid #e5e7eb;
                border-left: 0;
            }

            .dark .stb-withdrawal-fee + .stb-withdrawal-fee {
                border-color: #374151;
            }

            .stb-withdrawal-guide__footer {
                align-items: flex-start;
                flex-direction: column;
            }
        }
    </style>
@endonce

<x-filament-widgets::widget>
    <x-filament::section
        heading="Panduan Saldo & Penarikan Dana"
        description="Jadwal settlement dan ketentuan pencairan saldo melalui Pakasir."
        icon="heroicon-o-building-library"
        icon-color="warning"
        collapsible
        collapsed
        persist-collapsed
        collapse-id="pakasir-withdrawal-guide"
    >
        <div class="stb-withdrawal-guide">
            <div class="stb-withdrawal-guide__cards">
                <article class="stb-withdrawal-card stb-withdrawal-card--settlement">
                    <div class="stb-withdrawal-card__header">
                        <span class="stb-withdrawal-card__icon">
                            <x-heroicon-o-clock style="display: block; width: 1.2rem; height: 1.2rem;" />
                        </span>
                        <div>
                            <h3 class="stb-withdrawal-card__title">Settlement saldo QRIS</h3>
                            <p class="stb-withdrawal-card__schedule">Settlement H+1, pukul 12.00 WIB</p>
                        </div>
                    </div>
                    <p class="stb-withdrawal-card__body">
                        Transaksi berhasil masuk ke <strong>Saldo Tertunda</strong> terlebih dahulu. Pada esok hari pukul 12.00 WIB, saldo dipindahkan ke saldo utama dan siap ditarik. Settlement tidak dihitung 24 jam setelah transaksi.
                    </p>
                </article>

                <article class="stb-withdrawal-card">
                    <div class="stb-withdrawal-card__header">
                        <span class="stb-withdrawal-card__icon stb-withdrawal-card__icon--manual">
                            <x-heroicon-o-hand-raised style="display: block; width: 1.2rem; height: 1.2rem;" />
                        </span>
                        <div>
                            <h3 class="stb-withdrawal-card__title">Penarikan Manual</h3>
                            <p class="stb-withdrawal-card__subtitle">Ditransfer manual oleh tim kami</p>
                        </div>
                        <span class="stb-withdrawal-card__badge">Tanpa biaya</span>
                    </div>
                    <ul class="stb-withdrawal-list">
                        <li><span>Pengajuan hanya hari <strong>Jumat</strong>.</span></li>
                        <li><span>Diproses hari <strong>Sabtu, 09.00&ndash;12.00 WIB</strong>.</span></li>
                        <li><span>Maksimal penarikan <strong>Rp 500.000</strong>.</span></li>
                        <li><span>Penghasilan 24 jam terakhir maksimal <strong>Rp 100.000</strong>.</span></li>
                    </ul>
                </article>

                <article class="stb-withdrawal-card">
                    <div class="stb-withdrawal-card__header">
                        <span class="stb-withdrawal-card__icon stb-withdrawal-card__icon--automatic">
                            <x-heroicon-o-bolt style="display: block; width: 1.2rem; height: 1.2rem;" />
                        </span>
                        <div>
                            <h3 class="stb-withdrawal-card__title">Penarikan Otomatis</h3>
                            <p class="stb-withdrawal-card__subtitle">Diproses melalui API pihak ketiga</p>
                        </div>
                    </div>
                    <ul class="stb-withdrawal-list stb-withdrawal-list--automatic">
                        <li><span>Dapat diajukan <strong>Senin&ndash;Sabtu</strong>.</span></li>
                        <li><span>Jam layanan <strong>09.00&ndash;16.00 WIB</strong>.</span></li>
                        <li><span>Biaya admin mulai dari <strong>Rp 3.000</strong>.</span></li>
                    </ul>
                </article>
            </div>

            <section class="stb-withdrawal-fees" aria-labelledby="automatic-withdrawal-fees-title">
                <div class="stb-withdrawal-fees__header" id="automatic-withdrawal-fees-title">
                    Biaya admin penarikan otomatis
                </div>
                <div class="stb-withdrawal-fees__grid">
                    <div class="stb-withdrawal-fee">
                        <p class="stb-withdrawal-fee__range">Rp 15.000&ndash;Rp 4.999.999</p>
                        <p class="stb-withdrawal-fee__amount">Rp 3.000</p>
                    </div>
                    <div class="stb-withdrawal-fee">
                        <p class="stb-withdrawal-fee__range">Rp 5.000.000&ndash;Rp 9.999.999</p>
                        <p class="stb-withdrawal-fee__amount">Rp 5.000</p>
                    </div>
                    <div class="stb-withdrawal-fee">
                        <p class="stb-withdrawal-fee__range">Rp 10.000.000 ke atas</p>
                        <p class="stb-withdrawal-fee__amount">Rp 7.000</p>
                    </div>
                </div>
            </section>

            <footer class="stb-withdrawal-guide__footer">
                <p>Ketentuan layanan Pakasir, dikelola oleh <strong>PT. Geksa</strong>.</p>
                <nav class="stb-withdrawal-guide__links" aria-label="Tautan layanan Pakasir">
                    <a href="https://heylink.me/geksa-ecosystem" target="_blank" rel="noopener noreferrer">Geksa Support</a>
                    <a href="https://www.webkus.com/" target="_blank" rel="noopener noreferrer">Webkus</a>
                </nav>
            </footer>
        </div>
    </x-filament::section>
</x-filament-widgets::widget>
