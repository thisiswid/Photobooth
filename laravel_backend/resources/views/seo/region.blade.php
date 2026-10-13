@extends('layouts.marketing')

@php
    $seo = config('seo_pages');
    $waUrl = 'https://wa.me/'.$seo['business']['whatsapp'].'?text='.rawurlencode("Halo SnapTechBooth, saya ingin tanya photobooth untuk acara di {$page['name']}.");
    $otherRegion = $slug === 'photobooth-jawa-timur'
        ? ['photobooth-jawa-tengah', 'Jawa Tengah']
        : ['photobooth-jawa-timur', 'Jawa Timur'];
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
                <span class="label -rotate-2 text-ink">{{ $cities->count() }} kota • Base di Magetan</span>
                <h1 class="display mt-6 text-4xl leading-[1.08] drop-shadow-[3px_4px_0_#2c201a] sm:text-6xl">{{ $page['h1'] }}</h1>
                <p class="mt-6 max-w-xl text-base font-semibold leading-relaxed text-paper/95 lg:text-lg">{{ $page['lead'] }}</p>
                <div class="mt-8 flex flex-col gap-3 sm:flex-row">
                    <a href="{{ $waUrl }}" target="_blank" rel="noopener" class="btn btn-shadow bg-mustard text-ink">Cek jadwal via WhatsApp ↗</a>
                    <a href="#kota" class="btn bg-paper text-ink">Pilih kota ↓</a>
                </div>
            </div>
            <figure class="hero-figure mx-auto w-full max-w-[480px]">
                <img src="/images/seo/area-layanan.webp" width="960" height="720" alt="Ilustrasi photobooth dari Magetan ke kota-kota di {{ $page['name'] }}" fetchpriority="high">
            </figure>
        </div>
    </section>

    <section id="kota" class="bg-paper py-20 sm:py-24">
        <div class="mx-auto max-w-7xl px-5 lg:px-8">
            <h2 class="display mb-12 text-3xl leading-tight sm:text-5xl">Kota di {{ $page['name'] }} yang kami layani</h2>
            @include('seo.partials.city-tiers', ['cities' => $cities])
            <p class="mt-12 text-sm font-semibold text-ink/65">Kota kamu tidak ada di daftar? Tetap tanyakan saja lewat WhatsApp. Lihat juga <a href="/{{ $otherRegion[0] }}" class="font-black text-tomato">photobooth {{ $otherRegion[1] }} →</a></p>
        </div>
    </section>

    <section class="border-y-2 border-ink bg-mustard py-20">
        <div class="mx-auto max-w-7xl px-5 lg:px-8">
            <h2 class="display text-3xl sm:text-5xl">Layanan di {{ $page['name'] }}</h2>
            <ul class="mt-10 grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
                @foreach ($seo['services'] as $s => $svc)
                    <li><a href="/{{ $s }}" class="card block h-full rounded-2xl p-5"><b class="display text-xl">{{ $svc['name'] }}</b><p class="mt-2 text-sm font-medium text-ink/65">{{ $svc['eyebrow'] }}</p></a></li>
                @endforeach
            </ul>
        </div>
    </section>

    <section class="sunburst-teal py-16 text-paper">
        <div class="mx-auto flex max-w-7xl flex-col items-start gap-6 px-5 lg:flex-row lg:items-center lg:justify-between lg:px-8">
            <h2 class="display max-w-2xl text-3xl leading-tight drop-shadow-[3px_3px_0_#2c201a] sm:text-4xl">Punya acara di {{ $page['name'] }}? Kami cek jadwalnya.</h2>
            <a href="{{ $waUrl }}" target="_blank" rel="noopener" class="btn btn-shadow shrink-0 bg-mustard text-ink">Chat WhatsApp ↗</a>
        </div>
    </section>
@endsection
