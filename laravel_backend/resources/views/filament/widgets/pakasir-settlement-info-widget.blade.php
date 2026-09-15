<x-filament-widgets::widget>
    <x-filament::section
        heading="Informasi Saldo dan Settlement Pakasir"
        icon="heroicon-o-clock"
        icon-color="warning"
    >
        <div class="space-y-3 text-sm text-gray-600 dark:text-gray-300">
            <p>
                Transaksi QRIS yang berhasil akan masuk lebih dahulu ke <strong>Saldo Tertunda</strong> di Pakasir.
                Saldo tersebut belum dapat dicairkan sebelum proses settlement selesai.
            </p>

            <div class="rounded-lg bg-warning-50 p-4 text-warning-800 ring-1 ring-inset ring-warning-200 dark:bg-warning-950/30 dark:text-warning-200 dark:ring-warning-800">
                <p class="font-semibold">Settlement H+1, pukul 12.00 WIB</p>
                <p class="mt-1">
                    Saldo dari transaksi hari ini akan dipindahkan ke saldo utama Pakasir pada esok hari pukul 12.00 WIB.
                    Waktunya bukan dihitung 24 jam sejak masing-masing transaksi.
                </p>
            </div>

            <p>
                Ketentuan H+1 pukul 12.00 WIB ini berlaku di Pakasir sejak 12 April 2026.
                Karena itu, saldo transaksi pada sistem photobooth dapat sementara berbeda dengan saldo utama yang sudah siap dicairkan di Pakasir.
            </p>
        </div>
    </x-filament::section>
</x-filament-widgets::widget>
