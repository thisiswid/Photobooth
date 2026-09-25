@auth
    @php
        $tour = \App\Support\AdminGuide::tour(request()->route()?->getName() ?? '');
        $tour['user'] = (string) auth()->id();
        $tour['docs'] = \App\Filament\Pages\Documentation::getUrl();
    @endphp
    <link rel="stylesheet" href="{{ asset('css/admin-guide.css') }}?v=1">
    <div id="photobooth-guide-config" data-config="{{ json_encode($tour) }}" hidden></div>
    <button id="photobooth-help" type="button" aria-label="Buka tutorial halaman ini" title="Tutorial halaman ini">?</button>
    <script src="{{ asset('js/admin-guide.js') }}?v=1" defer></script>
@endauth
