<?php

namespace App\Filament\SuperAdmin\Resources;

use App\Filament\SuperAdmin\Resources\GlobalActivityLogResource\Pages;
use App\Models\ActivityLog;
use Filament\Actions\ViewAction;
use Filament\Infolists\Components\KeyValueEntry;
use Filament\Infolists\Components\Section;
use Filament\Infolists\Components\TextEntry;
use Filament\Resources\Resource;
use Filament\Schemas\Schema;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Filters\SelectFilter;
use Filament\Tables\Table;

class GlobalActivityLogResource extends Resource
{
    protected static ?string $model = ActivityLog::class;

    public static function getNavigationIcon(): string { return 'heroicon-o-finger-print'; }
    public static function getNavigationGroup(): string { return 'Security & Access'; }
    public static function getNavigationSort(): int { return 3; }
    public static function getModelLabel(): string { return 'Audit Log & Keamanan'; }
    public static function getPluralModelLabel(): string { return 'Audit Trail & Aktivitas'; }

    public static function form(Schema $schema): Schema
    {
        return $schema->components([]);
    }

    public static function infolist(Schema $schema): Schema
    {
        return $schema->components([
            Section::make('Rincian Log Aktivitas Keamanan')->schema([
                TextEntry::make('id')->label('Log ID'),
                TextEntry::make('user.name')->label('Pengguna')->placeholder('Sistem / Tamu'),
                TextEntry::make('cafe.name')->label('Cafe / Mitra')->placeholder('Global / Super Admin'),
                TextEntry::make('action')->label('Aksi')->badge()
                    ->color(fn ($state) => match(strtolower($state)) {
                        'login', 'create' => 'success',
                        'login_failed', 'delete' => 'danger',
                        'update' => 'warning',
                        'logout' => 'gray',
                        default => 'info',
                    }),
                TextEntry::make('ip_address')->label('IP Address')->copyable(),
                TextEntry::make('created_at')->label('Waktu Kejadian')->dateTime('d M Y H:i:s'),
                TextEntry::make('description')->label('Deskripsi')->columnSpanFull(),
                TextEntry::make('user_agent')->label('User Agent / Browser')->columnSpanFull(),
            ])->columns(3),

            Section::make('Data Tambahan (Payload / Diff)')
                ->schema([
                    KeyValueEntry::make('properties')->label('Data Detail'),
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
                    ->label('Pengguna')
                    ->placeholder('Sistem / Guest')
                    ->searchable()
                    ->sortable(),
                TextColumn::make('cafe.name')
                    ->label('Mitra')
                    ->badge()
                    ->color('primary')
                    ->placeholder('SuperAdmin')
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
                    })
                    ->sortable(),
                TextColumn::make('description')
                    ->label('Deskripsi')
                    ->searchable()
                    ->limit(50),
                TextColumn::make('ip_address')
                    ->label('IP Address')
                    ->copyable()
                    ->searchable(),
            ])
            ->defaultSort('created_at', 'desc')
            ->filters([
                SelectFilter::make('action')
                    ->options([
                        'login' => 'Login Sukses',
                        'login_failed' => 'Login Gagal (Security)',
                        'logout' => 'Logout',
                        'create' => 'Create Record',
                        'update' => 'Update Record',
                        'delete' => 'Delete Record',
                    ]),
            ])
            ->actions([
                ViewAction::make(),
            ]);
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListGlobalActivityLogs::route('/'),
        ];
    }
}
