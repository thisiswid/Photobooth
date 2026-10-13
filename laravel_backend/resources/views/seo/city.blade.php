@extends('layouts.marketing')

@php
    $seo = config('seo_pages');
    $waText = $isRemote
        ? "Halo SnapTechBooth, saya di {$page['name']} dan ingin tanya software photobooth."
        : "Halo SnapTechBooth, saya ingin tanya photobooth untuk acara di {$page['name']}.";
    $waUrl = 'https://wa.me/'.$seo['business']['whatsapp'].'?text='.rawurlencode($waText);
    $nearby = collect($page['nearby'])->mapWithKeys(fn ($s) => [$s => $seo['cities'][$s]]);
    $regionSlug = match ($page['province']) {
        'Jawa Timur' => 'photobooth-jawa-timur',
        'Jawa Tengah' => 'photobooth-jawa-tengah',
        default => null,
    };
    $serviceOrder = $isRemote
        ? ['aplikasi-photobooth', 'photobooth-cafe', 'photobooth-event', 'photobooth-wedding', 'photobooth-wisuda', 'sewa-photobooth']
        : ['photobooth-wedding', 'photobooth-event', 'photobooth-wisuda', 'photobooth-cafe', 'sewa-photobooth', 'aplikasi-photobooth'];
    $booking = $isRemote
        ? [
            ['Konsultasi kebutuhan', 'Ceritakan jenis usaha, jumlah booth, dan perangkat yang sudah kamu punya.'],
            ['Rekomendasi perangkat', 'Kami bantu memilih tablet atau PC, kamera, dan printer foto yang cocok.'],
            ['Instalasi & aktivasi jarak jauh', 'Aplikasi kiosk dipasang dan device diaktifkan dari jarak jauh dengan panduan langkah demi langkah.'],
            ['Atur frame & mulai jalan', 'Upload frame, atur harga sesi QRIS, dan pantau transaksi dari dashboard.'],
        ]
        : [
            ['Chat via WhatsApp', "Kirim tanggal, lokasi acara di {$page['name']}, dan jenis acaranya."],
            ['Cek jadwal & penawaran', 'Kami cek ketersediaan, estimasi perjalanan dari Magetan, lalu kirim penawaran.'],
            ['Desain frame', 'Frame disiapkan sesuai nama, tema, atau logo acara dan bisa direvisi sebelum hari H.'],
            ['Hari acara', 'Tim datang lebih awal untuk memasang booth, lalu tamu bisa langsung foto, cetak, dan scan QR.'],
        ];
@endphp

@section('content')
    <nav aria-label="Breadcrumb" class="border-b-2 border-ink bg-paper">
        <ol class="mx-auto flex max-w-7xl flex-wrap items-center gap-2 px-5 py-3 text-xs font-bold lg:px-8">
            <li><a href="/" class="text-ink/60 hover:text-tomato">Beranda</a></li>
            <li aria-hidden="true" class="text-ink/40">/</li>
            <li><a href="/area-layanan" class="text-ink/60 hover:text-tomato">Area Layanan</a></li>
            <li aria-hidden="true" class="text-ink/40">/</li>
            <li aria-current="page">Photobooth {{ $page['name'] }}</li>
        </ol>
    </nav>

    <section class="sunburst border-b-2 border-ink py-14 sm:py-20">
        <div class="mx-auto grid max-w-7xl items-center gap-12 px-5 lg:grid-cols-[1.1fr_.9fr] lg:px-8">
            <div class="text-paper">
                <span class="label -rotate-2 text-ink">{{ $tier['label'] }} • {{ $page['province'] }}</span>
                <h1 class="display mt-6 text-5xl leading-[1.05] drop-shadow-[3px_4px_0_#2c201a] sm:text-6xl lg:text-7xl">Photobooth {{ $fullName }}</h1>
                <p class="mt-4 text-xl font-black text-paper underline decoration-mustard decoration-4 underline-offset-8">
                    {{ $isRemote ? 'Software photobooth self-service untuk cafe & vendor' : 'Untuk wedding, event, wisuda, dan cafe' }}
                </p>
                <p class="mt-5 max-w-xl text-base font-semibold leading-relaxed text-paper/95 lg:text-lg">{{ $page['intro'] }}</p>
                <div class="mt-8 flex flex-col gap-3 sm:flex-row">
                    <a href="{{ $waUrl }}" target="_blank" rel="noopener" class="btn btn-shadow bg-mustard text-ink">Cek jadwal via WhatsApp ↗</a>
                    <a href="#layanan" class="btn bg-paper text-ink">Lihat layanan ↓</a>
                </div>
            </div>

            <div class="space-y-6">
                <figure class="hero-figure mx-auto w-full max-w-[460px]">
                    <img src="/images/seo/area-layanan.webp" width="960" height="720" alt="Ilustrasi photobooth berangkat dari Magetan menuju {{ $page['name'] }}" fetchpriority="high">
                </figure>
                <dl class="card mx-auto grid max-w-[460px] grid-cols-2 gap-4 rounded-3xl p-6 text-ink">
                    <div><dt class="text-[10px] font-black uppercase tracking-[.18em] text-ink/55">Base</dt><dd class="mt-1 text-lg font-black">Magetan</dd></div>
                    <div><dt class="text-[10px] font-black uppercase tracking-[.18em] text-ink/55">Provinsi</dt><dd class="mt-1 text-lg font-black">{{ $page['province'] }}</dd></div>
                    <div class="col-span-2 border-t-2 border-dashed border-ink/25 pt-4"><dt class="text-[10px] font-black uppercase tracking-[.18em] text-ink/55">Status jangkauan</dt><dd class="mt-1 text-sm font-semibold leading-relaxed">{{ $tier['note'] }}</dd></div>
                </dl>
            </div>
        </div>
    </section>

    <section class="bg-paper py-20 sm:py-24">
        <div class="mx-auto grid max-w-7xl gap-12 px-5 lg:grid-cols-[1.1fr_.9fr] lg:px-8">
            <div class="prose-snap">
                <h2 class="display text-3xl leading-tight sm:text-5xl">{{ $isRemote ? 'Photobooth self-service' : 'Photobooth untuk acara' }} di {{ $page['name'] }}</h2>
                <p class="mt-6 text-base sm:text-lg">{{ $page['local'] }}</p>
                <p class="mt-4 text-base sm:text-lg">Setiap sesi menghasilkan photo strip cetak 300 DPI, serta foto, GIF, dan video pendek yang bisa diunduh lewat QR code. Frame bisa didesain dengan nama, logo, atau tema acara.</p>
            </div>
            <div>
                <h3 class="text-xs font-black uppercase tracking-[.18em] text-teal">Sering dipakai untuk</h3>
                <ul class="mt-5 flex flex-wrap gap-3">
                    @foreach ($page['venues'] as $v)
                        <li class="chip shadow-[3px_3px_0_#2c201a]">{{ $v }}</li>
                    @endforeach
                </ul>
            </div>
        </div>
    </section>

    <section id="layanan" class="border-y-2 border-ink bg-mustard py-20 sm:py-24">
        <div class="mx-auto max-w-7xl px-5 lg:px-8">
            <h2 class="display text-3xl leading-tight sm:text-5xl">Layanan di {{ $page['name'] }}</h2>
            <ul class="mt-10 grid gap-5 sm:grid-cols-2 lg:grid-cols-3">
                @foreach ($serviceOrder as $s)
                    @php $svc = $seo['services'][$s]; @endphp
                    <li>
                        <a href="/{{ $s }}" class="card flex h-full items-center gap-4 rounded-3xl p-4">
                            <img src="/images/seo/{{ $svc['image'] }}.webp" width="120" height="90" loading="lazy" alt="" class="w-24 shrink-0 rounded-xl border-2 border-ink">
                            <span><b class="display block text-xl leading-tight">{{ $svc['name'] }}</b><small class="mt-1 block text-xs font-semibold text-ink/60">{{ $svc['eyebrow'] }}</small></span>
                        </a>
                    </li>
                @endforeach
            </ul>
        </div>
    </section>

    <section class="py-20 sm:py-24">
        <div class="mx-auto grid max-w-7xl gap-12 px-5 lg:grid-cols-[.8fr_1.2fr] lg:px-8">
            <div>
                <span class="label bg-paper">{{ $isRemote ? 'Cara mulai' : 'Cara pesan' }}</span>
                <h2 class="display mt-6 text-3xl leading-tight sm:text-5xl">{{ $isRemote ? 'Mulai dari jarak jauh' : 'Pesan photobooth untuk '.$page['name'] }}</h2>
            </div>
            <ol class="space-y-4">
                @foreach ($booking as $i => [$title, $text])
                    <li class="card flex gap-4 rounded-2xl p-5">
                        <span class="step-num">{{ $i + 1 }}</span>
                        <div><h3 class="text-lg font-black">{{ $title }}</h3><p class="mt-1 text-sm font-medium leading-relaxed text-ink/65">{{ $text }}</p></div>
                    </li>
                @endforeach
            </ol>
        </div>
    </section>

    <section class="border-t-2 border-ink bg-paper py-20 sm:py-24">
        <div class="mx-auto max-w-4xl px-5 lg:px-8">
            <h2 class="display text-center text-3xl sm:text-5xl">Tanya jawab photobooth {{ $page['name'] }}</h2>
            <div class="mt-10 space-y-4">
                @foreach ($faq as [$q, $a])
                    <details class="rounded-2xl border-2 border-ink bg-cream p-5 shadow-[4px_5px_0_#2c201a]">
                        <summary class="flex items-center justify-between gap-4 font-black"><h3 class="text-base">{{ $q }}</h3><span class="plus grid h-9 w-9 shrink-0 place-items-center rounded-full border-2 border-ink bg-mustard text-xl" aria-hidden="true">+</span></summary>
                        <p class="mt-4 pr-10 text-sm font-medium leading-relaxed text-ink/70">{{ $a }}</p>
                    </details>
                @endforeach
            </div>
        </div>
    </section>

    <section class="border-t-2 border-ink py-16">
        <div class="mx-auto max-w-7xl px-5 lg:px-8">
            <h2 class="display text-2xl sm:text-3xl">Kota terdekat</h2>
            <ul class="mt-7 grid grid-cols-2 gap-3 sm:grid-cols-4">
                @foreach ($nearby as $s => $c)
                    <li><a href="/{{ $s }}" class="card block h-full rounded-2xl px-4 py-3"><b class="text-sm">Photobooth {{ $c['name'] }}</b><small class="block text-xs font-semibold text-ink/55">{{ $c['tier'] === 'base' ? 'Base kami' : $c['province'] }}</small></a></li>
                @endforeach
            </ul>
            <p class="mt-6 text-sm font-semibold text-ink/65">
                @if ($regionSlug)
                    <a href="/{{ $regionSlug }}" class="font-black text-tomato">Semua kota di {{ $page['province'] }} →</a> ·
                @endif
                <a href="/area-layanan" class="font-black text-tomato">Semua area layanan →</a>
            </p>
        </div>
    </section>

    <section class="sunburst-teal border-t-2 border-ink py-16 text-paper">
        <div class="mx-auto flex max-w-7xl flex-col items-start gap-6 px-5 lg:flex-row lg:items-center lg:justify-between lg:px-8">
            <div class="max-w-2xl">
                <h2 class="display text-3xl leading-tight drop-shadow-[3px_3px_0_#2c201a] sm:text-4xl">{{ $isRemote ? "Jalankan photobooth sendiri di {$page['name']}." : "Ada acara di {$page['name']}? Cek jadwalnya dulu." }}</h2>
                <p class="mt-3 font-medium text-paper/85">Balasan via WhatsApp, langsung dengan tim kami di Magetan.</p>
            </div>
            <a href="{{ $waUrl }}" target="_blank" rel="noopener" class="btn btn-shadow shrink-0 bg-mustard text-ink">Chat WhatsApp ↗</a>
        </div>
    </section>
@endsection
