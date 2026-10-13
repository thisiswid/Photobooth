{{-- Daftar kota dikelompokkan per tingkat jangkauan. Variabel: $cities (Collection slug => city) --}}
@php $tiers = config('seo_pages.tiers'); @endphp
<div class="space-y-12">
    @foreach ($tiers as $tierKey => $tier)
        @php $group = $cities->filter(fn ($c) => $c['tier'] === $tierKey); @endphp
        @continue($group->isEmpty())
        <div>
            <div class="flex flex-col gap-2 sm:flex-row sm:items-end sm:justify-between">
                <h3 class="display text-2xl sm:text-3xl">{{ $tier['label'] }}</h3>
                <p class="max-w-xl text-sm font-medium text-ink/65">{{ $tier['note'] }}</p>
            </div>
            <ul class="mt-6 grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
                @foreach ($group as $s => $c)
                    <li>
                        <a href="/{{ $s }}" class="card flex h-full flex-col rounded-2xl p-5">
                            <b class="display text-xl">Photobooth {{ $c['name'] }}</b>
                            <small class="mt-1 text-xs font-bold uppercase tracking-[.14em] text-teal">{{ $c['province'] }}</small>
                            <span class="mt-3 text-sm font-semibold text-ink/65">{{ $c['tier'] === 'base' ? 'Base SnapTechBooth' : $c['distance'].' · '.$c['drive'] }}</span>
                        </a>
                    </li>
                @endforeach
            </ul>
        </div>
    @endforeach
</div>
