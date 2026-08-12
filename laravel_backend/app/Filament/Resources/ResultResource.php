<?php

namespace App\Filament\Resources;

use App\Filament\Resources\ResultResource\Pages;
use App\Models\Result;
use Filament\Schemas\Schema;
use Filament\Infolists\Components\ImageEntry;
use Filament\Infolists\Components\Section;
use Filament\Infolists\Components\TextEntry;
use Filament\Resources\Resource;
use Filament\Actions\ViewAction;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Table;

class ResultResource extends Resource
{
    protected static ?string $model = Result::class;

    public static function getNavigationIcon(): string { return 'heroicon-o-qr-code'; }
    public static function getNavigationGroup(): string { return 'Operasional'; }
    public static function getNavigationSort(): int { return 3; }
    public static function getModelLabel(): string { return 'Hasil'; }
    public static function getPluralModelLabel(): string { return 'Hasil'; }

    public static function form(Schema $schema): Schema
    {
        return $schema->components([]);
    }

    public static function infolist(Schema $schema): Schema
    {
        return $schema->components([
            Section::make('Hasil Sesi')->schema([
                TextEntry::make('session_id')->label('ID Sesi'),
                TextEntry::make('qr_token')->label('QR Token'),
                TextEntry::make('expires_at')->label('Expired')->dateTime('d M Y H:i:s'),
            ])->columns(3),
            Section::make('File')->schema([
                ImageEntry::make('final_url')->label('Hasil Final'),
                ImageEntry::make('gif_url')->label('GIF'),
            ])->columns(2),
        ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                TextColumn::make('id')->sortable(),
                TextColumn::make('session_id')->label('ID Sesi'),
                TextColumn::make('qr_token')->label('QR Token')->searchable(),
                TextColumn::make('expires_at')->label('Expired')->dateTime('d M Y H:i')->sortable(),
                TextColumn::make('created_at')->label('Dibuat')->dateTime('d M Y H:i')->sortable(),
            ])
            ->defaultSort('id', 'desc')
            ->actions([ViewAction::make()]);
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListResults::route('/'),
            'view'  => Pages\ViewResult::route('/{record}'),
        ];
    }
}
