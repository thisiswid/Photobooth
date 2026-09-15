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
        <div class="space-y-6 text-sm text-gray-600 dark:text-gray-300">
            <div class="grid gap-4 lg:grid-cols-3">
                <div class="rounded-xl bg-warning-50 p-5 ring-1 ring-inset ring-warning-200 dark:bg-warning-950/30 dark:ring-warning-800">
                    <div class="flex items-start gap-3">
                        <div class="rounded-lg bg-warning-100 p-2 text-warning-700 dark:bg-warning-900/50 dark:text-warning-300">
                            <x-heroicon-o-clock class="h-5 w-5" style="display: block; width: 1.25rem; height: 1.25rem;" />
                        </div>
                        <div>
                            <p class="font-semibold text-gray-950 dark:text-white">Settlement saldo QRIS</p>
                            <p class="mt-1 text-xs font-semibold uppercase tracking-wide text-warning-700 dark:text-warning-300">
                                Settlement H+1, pukul 12.00 WIB
                            </p>
                        </div>
                    </div>
                    <p class="mt-4 leading-6">
                        Transaksi berhasil masuk ke <strong>Saldo Tertunda</strong> terlebih dahulu, lalu berpindah ke saldo utama pada esok hari pukul 12.00 WIB. Waktunya bukan 24 jam setelah transaksi.
                    </p>
                </div>

                <div class="rounded-xl bg-white p-5 ring-1 ring-inset ring-gray-200 dark:bg-gray-900 dark:ring-white/10">
                    <div class="flex items-start justify-between gap-3">
                        <div class="flex items-start gap-3">
                            <div class="rounded-lg bg-success-50 p-2 text-success-600 dark:bg-success-950/40 dark:text-success-400">
                                <x-heroicon-o-hand-raised class="h-5 w-5" style="display: block; width: 1.25rem; height: 1.25rem;" />
                            </div>
                            <div>
                                <p class="font-semibold text-gray-950 dark:text-white">Penarikan Manual</p>
                                <p class="mt-1 text-xs text-gray-500 dark:text-gray-400">Ditransfer manual oleh tim kami</p>
                            </div>
                        </div>
                        <span class="rounded-full bg-success-50 px-2.5 py-1 text-xs font-semibold text-success-700 dark:bg-success-950/40 dark:text-success-300">Gratis</span>
                    </div>
                    <ul class="mt-4 space-y-2 leading-6">
                        <li class="flex gap-2"><span class="text-success-500">&bull;</span><span>Pengajuan hanya hari <strong>Jumat</strong>.</span></li>
                        <li class="flex gap-2"><span class="text-success-500">&bull;</span><span>Diproses hari <strong>Sabtu, 09.00&ndash;12.00 WIB</strong>.</span></li>
                        <li class="flex gap-2"><span class="text-success-500">&bull;</span><span>Maksimal penarikan <strong>Rp 500.000</strong>.</span></li>
                        <li class="flex gap-2"><span class="text-success-500">&bull;</span><span>Penghasilan 24 jam terakhir maksimal <strong>Rp 100.000</strong>.</span></li>
                    </ul>
                </div>

                <div class="rounded-xl bg-white p-5 ring-1 ring-inset ring-gray-200 dark:bg-gray-900 dark:ring-white/10">
                    <div class="flex items-start gap-3">
                        <div class="rounded-lg bg-primary-50 p-2 text-primary-600 dark:bg-primary-950/40 dark:text-primary-400">
                            <x-heroicon-o-bolt class="h-5 w-5" style="display: block; width: 1.25rem; height: 1.25rem;" />
                        </div>
                        <div>
                            <p class="font-semibold text-gray-950 dark:text-white">Penarikan Otomatis</p>
                            <p class="mt-1 text-xs text-gray-500 dark:text-gray-400">Diproses melalui API pihak ketiga</p>
                        </div>
                    </div>
                    <ul class="mt-4 space-y-2 leading-6">
                        <li class="flex gap-2"><span class="text-primary-500">&bull;</span><span>Dapat diajukan <strong>Senin&ndash;Sabtu</strong>.</span></li>
                        <li class="flex gap-2"><span class="text-primary-500">&bull;</span><span>Jam layanan <strong>09.00&ndash;16.00 WIB</strong>.</span></li>
                        <li class="flex gap-2"><span class="text-primary-500">&bull;</span><span>Biaya admin mulai dari <strong>Rp 3.000</strong>.</span></li>
                    </ul>
                </div>
            </div>

            <div class="overflow-hidden rounded-xl ring-1 ring-inset ring-gray-200 dark:ring-white/10">
                <div class="border-b border-gray-200 bg-gray-50 px-5 py-3 dark:border-white/10 dark:bg-white/5">
                    <p class="font-semibold text-gray-950 dark:text-white">Biaya admin penarikan otomatis</p>
                </div>
                <div class="grid divide-y divide-gray-200 dark:divide-white/10 sm:grid-cols-3 sm:divide-x sm:divide-y-0">
                    <div class="p-4">
                        <p class="text-xs text-gray-500 dark:text-gray-400">Rp 15.000&ndash;Rp 4.999.999</p>
                        <p class="mt-1 text-base font-semibold text-gray-950 dark:text-white">Rp 3.000</p>
                    </div>
                    <div class="p-4">
                        <p class="text-xs text-gray-500 dark:text-gray-400">Rp 5.000.000&ndash;Rp 9.999.999</p>
                        <p class="mt-1 text-base font-semibold text-gray-950 dark:text-white">Rp 5.000</p>
                    </div>
                    <div class="p-4">
                        <p class="text-xs text-gray-500 dark:text-gray-400">Rp 10.000.000 ke atas</p>
                        <p class="mt-1 text-base font-semibold text-gray-950 dark:text-white">Rp 7.000</p>
                    </div>
                </div>
            </div>

            <div class="flex flex-col gap-2 border-t border-gray-200 pt-4 text-xs text-gray-500 dark:border-white/10 dark:text-gray-400 sm:flex-row sm:items-center sm:justify-between">
                <p>Ketentuan layanan Pakasir, dikelola oleh <strong>PT. Geksa</strong>.</p>
                <div class="flex flex-wrap gap-x-4 gap-y-2">
                    <a href="https://heylink.me/geksa-ecosystem" target="_blank" rel="noopener noreferrer" class="font-semibold text-primary-600 hover:underline dark:text-primary-400">
                        Geksa Support
                    </a>
                    <a href="https://www.webkus.com/" target="_blank" rel="noopener noreferrer" class="font-semibold text-primary-600 hover:underline dark:text-primary-400">
                        Webkus
                    </a>
                </div>
            </div>
        </div>
    </x-filament::section>
</x-filament-widgets::widget>
