<?php

namespace App\Filament\Pages;

use Filament\Pages\Page;

class Documentation extends Page
{
    protected static ?string $slug = 'dokumentasi';

    protected static ?string $title = 'Dokumentasi Photobooth';

    protected static ?string $navigationLabel = 'Dokumentasi';

    protected static string|\BackedEnum|null $navigationIcon = 'heroicon-o-book-open';

    protected static string|\UnitEnum|null $navigationGroup = 'Bantuan';

    protected static ?int $navigationSort = 100;

    protected string $view = 'filament.pages.documentation';
}
