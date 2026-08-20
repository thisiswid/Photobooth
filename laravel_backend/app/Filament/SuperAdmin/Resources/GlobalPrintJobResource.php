<?php

namespace App\Filament\SuperAdmin\Resources;

use App\Filament\SuperAdmin\Resources\GlobalPrintJobResource\Pages;
use App\Models\PrintJob;
use Filament\Actions\ViewAction;
use Filament\Infolists\Components\ImageEntry;
use Filament\Infolists\Components\TextEntry;
use Filament\Resources\Resource;
use Filament\Schemas\Components\Section;
use Filament\Schemas\Schema;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Filters\SelectFilter;
use Filament\Tables\Table;

class GlobalPrintJobResource extends Resource
{
    protected static ?string $model = PrintJob::class;

    public static function getNavigationIcon(): string { return 'heroicon-o-printer'; }
    public static function getNavigationGroup(): string { return 'Operasional Global'; }
    public static function getNavigationSort(): int { return 3; }
    public static function getModelLabel(): string { return 'Antrian Cetak'; }
    public static function getPluralModelLabel(): string { return 'Semua Antrian Cetak'; }

    public static function form(Schema $schema): Schema
    {
        return $schema->components([]);
    }

    public static function infolist(Schema $schema): Schema
    {
        return $schema->components([
            Section::make('Rincian Cetak Foto & Lokasi')->schema([
                TextEntry::make('id')->label('Print Job ID'),
                TextEntry::make('session.cafe.name')->label('Lokasi Cafe')->badge()->color('primary')->placeholder('-'),
                TextEntry::make('session.id')->label('ID Sesi Foto'),
                TextEntry::make('session.event.name')->label('Event')->placeholder('Main Booth'),
                TextEntry::make('printer')->label('Nama / Tipe Printer')->placeholder('-'),
                TextEntry::make('status')->label('Status Cetak')->badge()
                    ->color(fn ($state) => match($state) {
                        'done'     => 'success',
                        'printing' => 'warning',
                        'failed'   => 'danger',
                        default    => 'gray',
                    }),
                TextEntry::make('printed_at')->label('Waktu Selesai Cetak')->dateTime('d M Y H:i:s')->placeholder('Belum selesai'),
                TextEntry::make('created_at')->label('Waktu Antrian Dibuat')->dateTime('d M Y H:i:s'),
            ])->columns(3),

            Section::make('Preview File Cetak & Frame')->schema([
                ImageEntry::make('session.result.final_url')
                    ->label('Foto Strip yang Dicetak')
                    ->disk('public')
                    ->placeholder('Belum ada file cetak'),
                TextEntry::make('session.frame.name')
                    ->label('Frame Digunakan')
                    ->placeholder('-'),
            ])->columns(2),
        ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                TextColumn::make('id')->label('ID')->sortable(),
                TextColumn::make('session.cafe.name')->label('Cafe')->badge()->color('primary')->searchable()->sortable(),
                TextColumn::make('session.id')->label('ID Sesi')->sortable(),
                TextColumn::make('printer')->label('Printer')->placeholder('-'),
                TextColumn::make('status')->label('Status')->badge()
                    ->color(fn ($state) => match($state) {
                        'done'     => 'success',
                        'printing' => 'warning',
                        'failed'   => 'danger',
                        default    => 'gray',
                    }),
                TextColumn::make('printed_at')->label('Dicetak')->dateTime('d M Y H:i')->placeholder('-')->sortable(),
                TextColumn::make('created_at')->label('Dibuat')->dateTime('d M Y H:i')->sortable(),
            ])
            ->defaultSort('id', 'desc')
            ->filters([
                SelectFilter::make('status')
                    ->options([
                        'pending'  => 'Pending',
                        'printing' => 'Printing',
                        'done'     => 'Done',
                        'failed'   => 'Failed',
                    ]),
            ])
            ->actions([
                ViewAction::make()->label('Detail'),
            ])
            ->poll('10s');
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListGlobalPrintJobs::route('/'),
            'view'  => Pages\ViewGlobalPrintJob::route('/{record}'),
        ];
    }
}
