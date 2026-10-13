@extends('layouts.marketing')

@php
    $seo = config('seo_pages');
    $waUrl = 'https://wa.me/'.$seo['business']['whatsapp'].'?text='.rawurlencode($page['wa']);
    $steps = [
        $page['first_step'],
        ['Pose dengan hitung mundur', 'Setiap pose diawali hitung mundur 5 detik. Kalau kurang puas, satu pose bisa diulang maksimal 2 kali.'],
        ['Pilih filter', 'Setelah semua pose selesai, pilih filter yang paling pas sebelum hasil akhir dibuat.'],
        ['Cetak & scan QR', 'Photo strip 300 DPI langsung dicetak, dan QR code muncul untuk mengunduh foto, GIF, dan video ke HP.'],
    ];
    $areaCities = collect($seo['cities'])->filter(fn ($c) => in_array($c['tier'], ['base', 'utama', 'reguler']));
    $remoteCities = collect($seo['cities'])->filter(fn ($c) => in_array($c['tier'], ['luar', 'jauh']));
    $others = collect($seo['services'])->except($slug);
@endphp

@section('content')
    {{-- Breadcrumb --}}
    <nav aria-label="Breadcrumb" class="border-b-2 border-ink bg-paper">
        <ol class="mx-auto flex max-w-7xl flex-wrap items-center gap-2 px-5 py-3 text-xs font-bold lg:px-8">
            <li><a href="/" class="text-ink/60 hover:text-tomato">Beranda</a></li>
            <li aria-hidden="true" class="text-ink/40">/</li>
            <li aria-current="page">{{ $page['name'] }}</li>
        </ol>
    </nav>

    {{-- Hero --}}
    <section class="sunburst border-b-2 border-ink py-14 sm:py-20">
        <div class="mx-auto grid max-w-7xl items-center gap-12 px-5 lg:grid-cols-[1.05fr_.95fr] lg:px-8">
            <div class="text-paper">
                <span class="label -rotate-2 text-ink">{{ $page['eyebrow'] }}</span>
                <h1 class="display mt-6 text-4xl leading-[1.08] drop-shadow-[3px_4px_0_#2c201a] sm:text-5xl lg:text-6xl">{{ $page['h1'] }}</h1>
                <p class="mt-6 max-w-xl text-base font-semibold leading-relaxed text-paper/95 lg:text-lg">{{ $page['lead'] }}</p>
                <div class="mt-8 flex flex-col gap-3 sm:flex-row">
                    <a href="{{ $waUrl }}" target="_blank" rel="noopener" class="btn btn-shadow bg-mustard text-ink">Tanya via WhatsApp ↗</a>
                    <a href="#cara-kerja" class="btn bg-paper text-ink">Lihat cara kerjanya ↓</a>
                </div>
            </div>
            <figure class="hero-figure mx-auto w-full max-w-[520px]">
                <img src="/images/seo/{{ $page['image'] }}.webp" width="960" height="720" alt="{{ $page['image_alt'] }}" fetchpriority="high">
            </figure>
        </div>
    </section>

    {{-- Why --}}
    <section class="bg-paper py-20 sm:py-24">
        <div class="mx-auto max-w-7xl px-5 lg:px-8">
            <h2 class="display max-w-3xl text-3xl leading-tight sm:text-5xl">{{ $page['why_title'] }}</h2>
            <div class="mt-12 grid gap-6 md:grid-cols-2">
                @foreach ($page['why'] as $i => [$title, $text])
                    <article class="card rounded-3xl p-7">
                        <span class="step-num {{ $i % 2 ? '!bg-teal text-paper' : '' }}">{{ str_pad($i + 1, 2, '0', STR_PAD_LEFT) }}</span>
                        <h3 class="display mt-5 text-2xl">{{ $title }}</h3>
                        <p class="mt-3 text-sm font-medium leading-relaxed text-ink/70">{{ $text }}</p>
                    </article>
                @endforeach
            </div>
        </div>
    </section>

    {{-- Steps --}}
    <section id="cara-kerja" class="border-y-2 border-ink py-20 sm:py-24">
        <div class="mx-auto grid max-w-7xl gap-12 px-5 lg:grid-cols-[.8fr_1.2fr] lg:px-8">
            <div>
                <span class="label bg-paper">Alur sesi</span>
                <h2 class="display mt-6 text-3xl leading-tight sm:text-5xl">Empat langkah, tanpa operator.</h2>
                <p class="mt-5 max-w-md font-medium leading-relaxed text-ink/70">Layar kiosk memandu setiap tamu dari awal sampai akhir. Satu sesi dibatasi 5 menit sejak foto dimulai, jadi antrean tetap bergerak.</p>
            </div>
            <ol class="space-y-4">
                @foreach ($steps as $i => [$title, $text])
                    <li class="card flex gap-4 rounded-2xl p-5">
                        <span class="step-num">{{ $i + 1 }}</span>
                        <div><h3 class="text-lg font-black">{{ $title }}</h3><p class="mt-1 text-sm font-medium leading-relaxed text-ink/65">{{ $text }}</p></div>
                    </li>
                @endforeach
            </ol>
        </div>
    </section>

    {{-- Suitable --}}
    <section class="bg-mustard py-16">
        <div class="mx-auto max-w-7xl px-5 lg:px-8">
            <h2 class="display text-3xl sm:text-4xl">Cocok untuk</h2>
            <ul class="mt-7 flex flex-wrap gap-3">
                @foreach ($page['suitable'] as $item)
                    <li class="chip shadow-[3px_3px_0_#2c201a]">{{ $item }}</li>
                @endforeach
            </ul>
        </div>
    </section>

    {{-- Area --}}
    <section class="bg-paper py-20 sm:py-24">
        <div class="mx-auto max-w-7xl px-5 lg:px-8">
            <div class="max-w-3xl">
                <span class="label bg-teal text-paper">Berangkat dari Magetan</span>
                <h2 class="display mt-6 text-3xl leading-tight sm:text-5xl">{{ $page['short'] === 'Aplikasi' ? 'Dipakai di mana saja' : 'Area yang kami layani' }}</h2>
                <p class="mt-5 font-medium leading-relaxed text-ink/70">
                    @if ($page['short'] === 'Aplikasi')
                        Software bisa dipasang dari jarak jauh di kota mana pun. Untuk pendampingan langsung, tim kami berbasis di Magetan dan menjangkau kota-kota di Jawa Timur dan Jawa Tengah.
                    @else
                        Base kami di Magetan, Jawa Timur. Kota-kota berikut bisa dijangkau langsung oleh tim. Untuk kota yang lebih jauh, tersedia layanan by request dan software photobooth.
                    @endif
                </p>
            </div>
            <ul class="mt-10 grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-4">
                @foreach ($areaCities as $citySlug => $city)
                    <li><a href="/{{ $citySlug }}" class="card flex h-full flex-col rounded-2xl px-4 py-3"><b class="text-sm">Photobooth {{ $city['name'] }}</b><small class="text-xs font-semibold text-ink/55">{{ $city['tier'] === 'base' ? 'Base kami' : $city['drive'] }}</small></a></li>
                @endforeach
            </ul>
            <p class="mt-6 text-sm font-semibold text-ink/65">Luar kota & jarak jauh:
                @foreach ($remoteCities as $citySlug => $city)
                    <a href="/{{ $citySlug }}" class="underline decoration-tomato decoration-2 underline-offset-4 hover:text-tomato">{{ $city['name'] }}</a>@if (! $loop->last), @endif
                @endforeach
                · <a href="/area-layanan" class="font-black text-tomato">Lihat semua area →</a>
            </p>
        </div>
    </section>

    {{-- FAQ --}}
    <section class="border-t-2 border-ink py-20 sm:py-24">
        <div class="mx-auto max-w-4xl px-5 lg:px-8">
            <h2 class="display text-center text-3xl sm:text-5xl">Pertanyaan seputar {{ strtolower($page['short']) === 'aplikasi' ? 'aplikasi photobooth' : 'photobooth '.strtolower($page['short']) }}</h2>
            <div class="mt-10 space-y-4">
                @foreach ($page['faq'] as [$q, $a])
                    <details class="rounded-2xl border-2 border-ink bg-paper p-5 shadow-[4px_5px_0_#2c201a]">
                        <summary class="flex items-center justify-between gap-4 font-black"><h3 class="text-base">{{ $q }}</h3><span class="plus grid h-9 w-9 shrink-0 place-items-center rounded-full border-2 border-ink bg-mustard text-xl" aria-hidden="true">+</span></summary>
                        <p class="mt-4 pr-10 text-sm font-medium leading-relaxed text-ink/70">{{ $a }}</p>
                    </details>
                @endforeach
            </div>
        </div>
    </section>

    {{-- Related --}}
    <section class="bg-paper py-16">
        <div class="mx-auto max-w-7xl px-5 lg:px-8">
            <h2 class="display text-2xl sm:text-3xl">Layanan lainnya</h2>
            <ul class="mt-7 grid gap-4 sm:grid-cols-2 lg:grid-cols-5">
                @foreach ($others as $s => $svc)
                    <li><a href="/{{ $s }}" class="card block h-full rounded-2xl p-5"><b class="display text-lg">{{ $svc['name'] }}</b><small class="mt-1 block text-xs font-semibold text-ink/60">{{ $svc['eyebrow'] }}</small></a></li>
                @endforeach
            </ul>
        </div>
    </section>

    {{-- CTA --}}
    <section class="sunburst-teal border-t-2 border-ink py-16 text-paper">
        <div class="mx-auto flex max-w-7xl flex-col items-start gap-6 px-5 lg:flex-row lg:items-center lg:justify-between lg:px-8">
            <div class="max-w-2xl">
                <h2 class="display text-3xl leading-tight drop-shadow-[3px_3px_0_#2c201a] sm:text-4xl">Ceritakan acaramu, kami siapkan booth-nya.</h2>
                <p class="mt-3 font-medium text-paper/85">Kirim tanggal, lokasi, dan jenis acara lewat WhatsApp. Kami cek jadwal dan kirim penawaran.</p>
            </div>
            <a href="{{ $waUrl }}" target="_blank" rel="noopener" class="btn btn-shadow shrink-0 bg-mustard text-ink">Chat WhatsApp ↗</a>
        </div>
    </section>
@endsection
