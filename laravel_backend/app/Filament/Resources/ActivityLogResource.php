<?php

namespace App\Filament\Resources;

use App\Filament\Resources\ActivityLogResource\Pages;
use App\Models\ActivityLog;
use Filament\Actions\ViewAction;
use Filament\Infolists\Components\KeyValueEntry;
use Filament\Infolists\Components\Section;
use Filament\Infolists\Components\TextEntry;
use Filament\Resources\Resource;
use Filament\Schemas\Schema;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Table;
use Illuminate\Database\Eloquent\Builder;

class ActivityLogResource extends Resource
{
    protected static ?string $model = ActivityLog::class;

    public static function getNavigationIcon(): string { return 'heroicon-o-shield-check'; }
    public static function getNavigationGroup(): string { return 'Pengaturan'; }
    public static function getNavigationSort(): int { return 99; }
    public static function getModelLabel(): string { return 'Log Aktivitas'; }
    public static function getPluralModelLabel(): string { return 'Audit Log Akun'; }

    public static function getEloquentQuery(): Builder
    {
        $query = parent::getEloquentQuery();
        if ($cafeId = auth()->user()?->cafe_id) {
            $query->where('cafe_id', $cafeId);
        }
        return $query->latest();
    }

    public static function form(Schema $schema): Schema
    {
        return $schema->components([]);
    }

    public static function infolist(Schema $schema): Schema
    {
        return $schema->components([
            Section::make('Rincian Log Aktivitas')->schema([
                TextEntry::make('user.name')->label('Pengguna')->placeholder('Sistem'),
                TextEntry::make('action')->label('Aksi')->badge()
                    ->color(fn ($state) => match(strtolower($state)) {
                        'login', 'create' => 'success',
                        'login_failed', 'delete' => 'danger',
                        'update' => 'warning',
                        'logout' => 'gray',
                        default => 'info',
                    }),
                TextEntry::make('ip_address')->label('IP Address'),
                TextEntry::make('created_at')->label('Waktu')->dateTime('d M Y H:i:s'),
                TextEntry::make('description')->label('Deskripsi')->columnSpanFull(),
            ])->columns(2),

            Section::make('Perubahan Data')
                ->schema([
                    KeyValueEntry::make('properties')->label('Detail Parameter'),
                ])
                ->visible(fn ($record) => !empty($record->properties)),
        ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                TextColumn::make('created_at')
                    ->label('Waktu')
                    ->dateTime('d M Y H:i:s')
                    ->sortable(),
                TextColumn::make('user.name')
                    ->label('User')
                    ->placeholder('Sistem')
                    ->searchable(),
                TextColumn::make('action')
                    ->label('Aksi')
                    ->badge()
                    ->color(fn ($state) => match(strtolower($state)) {
                        'login', 'create' => 'success',
                        'login_failed', 'delete' => 'danger',
                        'update' => 'warning',
                        'logout' => 'gray',
                        default => 'info',
                    }),
                TextColumn::make('description')
                    ->label('Aktivitas')
                    ->searchable()
                    ->limit(60),
                TextColumn::make('ip_address')
                    ->label('IP')
                    ->searchable(),
            ])
            ->defaultSort('created_at', 'desc')
            ->actions([
                ViewAction::make(),
            ]);
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListActivityLogs::route('/'),
        ];
    }
}
