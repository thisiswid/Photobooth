@once
    <style>
        .stb-dashboard-copyright {
            padding: 1rem 1.25rem .25rem;
            border-top: 1px solid #e5e7eb;
            color: #6b7280;
            font-size: .75rem;
            line-height: 1.5;
            text-align: center;
        }

        .stb-dashboard-copyright strong {
            color: #374151;
            font-weight: 700;
        }

        .dark .stb-dashboard-copyright {
            border-color: #374151;
            color: #9ca3af;
        }

        .dark .stb-dashboard-copyright strong {
            color: #f3f4f6;
        }
    </style>
@endonce

<x-filament-widgets::widget>
    <footer class="stb-dashboard-copyright">
        &copy; {{ now()->year }} <strong>SnapTechBooth</strong>. Hak cipta dilindungi.
    </footer>
</x-filament-widgets::widget>
