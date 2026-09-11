<?php

namespace App\Providers\Filament;

use App\Filament\SuperAdmin\Widgets\GlobalStatsOverviewWidget;
use App\Filament\SuperAdmin\Widgets\CafePerformanceWidget;
use Filament\Http\Middleware\Authenticate;
use Filament\Http\Middleware\DisableBladeIconComponents;
use Filament\Http\Middleware\DispatchServingFilamentEvent;
use Filament\Pages\Dashboard;
use Filament\Panel;
use Filament\PanelProvider;
use Filament\Support\Colors\Color;
use Illuminate\Cookie\Middleware\AddQueuedCookiesToResponse;
use Illuminate\Cookie\Middleware\EncryptCookies;
use Illuminate\Foundation\Http\Middleware\VerifyCsrfToken;
use Illuminate\Routing\Middleware\SubstituteBindings;
use Illuminate\Session\Middleware\AuthenticateSession;
use Illuminate\Session\Middleware\StartSession;
use Illuminate\View\Middleware\ShareErrorsFromSession;
use Illuminate\Support\Facades\Schema;

class SuperAdminPanelProvider extends PanelProvider
{
    public function panel(Panel $panel): Panel
    {
        try {
            if (Schema::hasTable('notifications')) {
                $panel->databaseNotifications();
            }
        } catch (\Throwable) {
            // Panel login harus tetap dapat dimuat sebelum migrasi/deploy DB selesai.
        }

        return $panel
            ->id('super_admin')
            ->path('super-admin')
            ->login()
            ->colors([
                'primary' => Color::Indigo,
                'gray'    => Color::Slate,
            ])
            ->brandName('Photobooth Platform Owner')
            ->discoverResources(in: app_path('Filament/SuperAdmin/Resources'), for: 'App\\Filament\\SuperAdmin\\Resources')
            ->discoverPages(in: app_path('Filament/SuperAdmin/Pages'), for: 'App\\Filament\\SuperAdmin\\Pages')
            ->pages([
                Dashboard::class,
            ])
            ->discoverWidgets(in: app_path('Filament/SuperAdmin/Widgets'), for: 'App\\Filament\\SuperAdmin\\Widgets')
            ->widgets([
                GlobalStatsOverviewWidget::class,
                \App\Filament\SuperAdmin\Widgets\ServerHealthWidget::class,
                CafePerformanceWidget::class,
                \App\Filament\SuperAdmin\Widgets\GlobalLatestErrorLogsWidget::class,
            ])
            ->middleware([
                EncryptCookies::class,
                AddQueuedCookiesToResponse::class,
                StartSession::class,
                AuthenticateSession::class,
                ShareErrorsFromSession::class,
                VerifyCsrfToken::class,
                SubstituteBindings::class,
                DisableBladeIconComponents::class,
                DispatchServingFilamentEvent::class,
            ])
            ->authMiddleware([
                Authenticate::class,
            ]);
    }
}
