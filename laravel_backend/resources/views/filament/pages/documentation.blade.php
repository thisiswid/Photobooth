<x-filament-panels::page>
    <div class="pb-docs">
        <section class="pb-docs-hero">
            <span class="pb-docs-eyebrow">PUSAT BANTUAN</span>
            <h2>Dari persiapan booth sampai foto dibawa pulang.</h2>
            <p>Ikuti panduan admin dan alur aplikasi di bawah ini. Butuh arahan langsung? Klik tombol <strong>?</strong> di pojok bawah setiap halaman admin.</p>
            <p>Persiapan awal: atur cafe & harga → buat event → pasangkan perangkat → siapkan frame, filter, konten & timer → uji satu sesi di kiosk.</p>
        </section>
        <nav id="guide-contents" class="pb-docs-card" aria-label="Daftar isi dokumentasi">
            <h2>Daftar isi</h2>
            @foreach (['admin' => 'Admin cafe', 'app' => 'Aplikasi kiosk'] as $group => $label)
                <h3>{{ $label }}</h3>
                <div class="pb-docs-links">
                    @foreach (config("photobooth-guide.$group") as $key => $guide)
                        <a href="#{{ $group }}-{{ $key }}">{{ $guide['title'] }}</a>
                    @endforeach
                </div>
            @endforeach
        </nav>
        @foreach (['admin' => 'Panduan admin', 'app' => 'Panduan aplikasi kiosk'] as $group => $label)
            <section id="guide-{{ $group }}" class="pb-docs-section">
                <h2>{{ $label }}</h2>
                <div class="pb-docs-grid">
                    @foreach (config("photobooth-guide.$group") as $key => $guide)
                        @php($screenshot = "images/documentation/{$group}-{$key}.png")
                        <article id="{{ $group }}-{{ $key }}" class="pb-docs-card">
                            <h3>{{ $guide['title'] }}</h3>
                            <p>{{ $guide['intro'] }}</p>
                            <ol>
                                @foreach ($guide['steps'] as $instruction)
                                    <li>{{ $instruction }}</li>
                                @endforeach
                            </ol>
                            <figure>
                                @if (is_file(public_path($screenshot)))
                                    <a href="{{ asset($screenshot) }}" target="_blank" rel="noopener" aria-label="Perbesar screenshot {{ $guide['title'] }}">
                                        <img src="{{ asset($screenshot) }}" alt="{{ $guide['shot'] }}" loading="lazy" width="1280" height="800">
                                    </a>
                                @else
                                    <div class="pb-docs-placeholder"><span aria-hidden="true">▧</span><strong>Tempat screenshot</strong><p>{{ $guide['shot'] }}</p></div>
                                @endif
                                <figcaption>{{ $guide['shot'] }}<br><code>public/{{ $screenshot }}</code></figcaption>
                            </figure>
                            <a class="pb-docs-back" href="#guide-contents">Kembali ke daftar isi ↑</a>
                        </article>
                    @endforeach
                </div>
            </section>
        @endforeach
        <aside class="pb-docs-card">
            <h2>Mengisi screenshot dokumentasi</h2>
            <p>Simpan gambar PNG sesuai nama file di bawah setiap tempat screenshot. Gambar akan tampil otomatis setelah file tersedia dan halaman dimuat ulang. Gunakan gambar yang jelas, disarankan lebar minimal 1280 px. Pakai data contoh dan samarkan pairing key, rekening, serta informasi pribadi.</p>
        </aside>
    </div>
</x-filament-panels::page>
