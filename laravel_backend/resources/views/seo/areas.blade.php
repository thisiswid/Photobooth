@extends('layouts.marketing')

@php
    $seo = config('seo_pages');
    $cities = collect($seo['cities']);
    $waUrl = 'https://wa.me/'.$seo['business']['whatsapp'].'?text='.rawurlencode('Halo SnapTechBooth, saya ingin cek apakah lokasi acara saya terjangkau.');
@endphp

@section('content')
    <nav aria-label="Breadcrumb" class="border-b-2 border-ink bg-paper">
        <ol class="mx-auto flex max-w-7xl flex-wrap items-center gap-2 px-5 py-3 text-xs font-bold lg:px-8">
            <li><a href="/" class="text-ink/60 hover:text-tomato">Beranda</a></li>
            <li aria-hidden="true" class="text-ink/40">/</li>
            <li aria-current="page">Area Layanan</li>
        </ol>
    </nav>

    <section class="sunburst border-b-2 border-ink py-14 sm:py-20">
        <div class="mx-auto grid max-w-7xl items-center gap-12 px-5 lg:grid-cols-[1.1fr_.9fr] lg:px-8">
            <div class="text-paper">
                <span class="label -rotate-2 text-ink">Base: Magetan, Jawa Timur</span>
                <h1 class="display mt-6 text-4xl leading-[1.08] drop-shadow-[3px_4px_0_#2c201a] sm:text-6xl">Area Layanan Photobooth SnapTechBooth</h1>
                <p class="mt-6 max-w-xl text-base font-semibold leading-relaxed text-paper/95 lg:text-lg">Kami berangkat dari Magetan, di perbatasan Jawa Timur dan Jawa Tengah. Kota-kota terdekat dilayani langsung oleh tim, kota yang lebih jauh by request, dan untuk Jakarta serta Bekasi kami fokus pada software photobooth yang dipasang dari jarak jauh.</p>
                <div class="mt-8 flex flex-col gap-3 sm:flex-row">
                    <a href="/photobooth-jawa-timur" class="btn btn-shadow bg-mustard text-ink">Jawa Timur</a>
                    <a href="/photobooth-jawa-tengah" class="btn bg-paper text-ink">Jawa Tengah</a>
                </div>
            </div>
            <figure class="hero-figure mx-auto w-full max-w-[480px]">
                <img src="/images/seo/area-layanan.webp" width="960" height="720" alt="Ilustrasi papan penunjuk arah dari Magetan ke Madiun, Solo, dan kota lain" fetchpriority="high">
            </figure>
        </div>
    </section>

    <section class="bg-paper py-20 sm:py-24">
        <div class="mx-auto max-w-7xl px-5 lg:px-8">
            <h2 class="display mb-4 text-3xl leading-tight sm:text-5xl">Semua kota yang kami layani</h2>
            <p class="mb-12 max-w-3xl font-medium text-ink/65">Jarak dan waktu tempuh adalah perkiraan dari pusat Magetan, tergantung rute dan lokasi acara.</p>
            @include('seo.partials.city-tiers', ['cities' => $cities])
        </div>
    </section>

    <section class="sunburst-teal border-t-2 border-ink py-16 text-paper">
        <div class="mx-auto flex max-w-7xl flex-col items-start gap-6 px-5 lg:flex-row lg:items-center lg:justify-between lg:px-8">
            <div class="max-w-2xl">
                <h2 class="display text-3xl leading-tight drop-shadow-[3px_3px_0_#2c201a] sm:text-4xl">Kotamu belum ada di daftar?</h2>
                <p class="mt-3 font-medium text-paper/85">Kirim lokasi acaramu, kami cek apakah bisa dijangkau atau cukup memakai software.</p>
            </div>
            <a href="{{ $waUrl }}" target="_blank" rel="noopener" class="btn btn-shadow shrink-0 bg-mustard text-ink">Cek lokasi via WhatsApp ↗</a>
        </div>
    </section>
@endsection
