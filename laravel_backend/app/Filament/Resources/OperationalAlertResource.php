<?php

namespace App\Filament\Resources;

use App\Filament\Resources\OperationalAlertResource\Pages;
use App\Models\OperationalAlert;
use Filament\Actions\Action;
use Filament\Notifications\Notification;
use Filament\Resources\Resource;
use Filament\Schemas\Schema;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Filters\SelectFilter;
use Filament\Tables\Table;
use Illuminate\Database\Eloquent\Builder;

class OperationalAlertResource extends Resource
{
    protected static ?string $model = OperationalAlert::class;

    public static function getNavigationIcon(): string
    {
        return 'heroicon-o-bell-alert';
    }

    public static function getNavigationGroup(): string
    {
        return 'Operasional';
    }

    public static function getNavigationSort(): int
    {
        return 1;
    }

    public static function getModelLabel(): string
    {
        return 'Peringatan Operasional';
    }

    public static function getPluralModelLabel(): string
    {
        return 'Peringatan Operasional';
    }

    public static function getNavigationBadge(): ?string
    {
        $query = static::getModel()::where('status', 'active');
        if ($cafeId = auth()->user()?->cafe_id) {
            $query->where('cafe_id', $cafeId);
        }

        return ($count = $query->count()) > 0 ? (string) $count : null;
    }

    public static function getNavigationBadgeColor(): string
    {
        return 'danger';
    }

    public static function form(Schema $schema): Schema
    {
        return $schema->components([]);
    }

    public static function table(Table $table): Table
    {
        return $table->columns([
            TextColumn::make('severity')->label('Level')->badge()->color(fn ($state) => $state),
            TextColumn::make('title')->label('Peringatan')->searchable()->weight('bold'),
            TextColumn::make('message')->label('Keterangan')->wrap()->limit(100),
            TextColumn::make('category')->label('Kategori')->badge(),
            TextColumn::make('status')->label('Status')->badge()->color(fn ($state) => $state === 'active' ? 'danger' : 'success'),
            TextColumn::make('last_detected_at')->label('Terakhir Terdeteksi')->dateTime('d M Y H:i:s')->sortable(),
        ])->defaultSort('last_detected_at', 'desc')->filters([
            SelectFilter::make('status')->options(['active' => 'Aktif', 'resolved' => 'Selesai'])->default('active'),
            SelectFilter::make('category')->options([
                'device_offline' => 'Mesin Offline', 'license_expiring' => 'Lisensi Hampir Habis',
                'license_expired' => 'Lisensi Habis', 'device_limit' => 'Slot Penuh',
                'payment_pending' => 'Pembayaran Pending', 'payment_reconciliation' => 'Rekonsiliasi',
                'withdrawal_pending' => 'Penarikan Pending',
            ]),
        ])->actions([
            Action::make('resolve')->label('Tandai Selesai')->icon('heroicon-o-check')->color('success')
                ->visible(fn ($record) => $record->status === 'active')
                ->action(function ($record): void {
                    $record->update(['status' => 'resolved', 'resolved_at' => now()]);
                    Notification::make()->title('Peringatan ditandai selesai')->success()->send();
                }),
        ])->poll('30s');
    }

    public static function getEloquentQuery(): Builder
    {
        $query = parent::getEloquentQuery();
        if ($cafeId = auth()->user()?->cafe_id) {
            $query->where('cafe_id', $cafeId);
        }

        return $query;
    }

    public static function getPages(): array
    {
        return ['index' => Pages\ListOperationalAlerts::route('/')];
    }
}
