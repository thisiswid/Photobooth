<?php

namespace App\Filament\Resources;

use App\Filament\Resources\PrintJobResource\Pages;
use App\Models\PrintJob;
use Filament\Schemas\Schema;
use Filament\Schemas\Components\Section;
use Filament\Infolists\Components\ImageEntry;
use Filament\Infolists\Components\TextEntry;
use Filament\Resources\Resource;
use Filament\Actions\ViewAction;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Filters\SelectFilter;
use Filament\Tables\Table;

class PrintJobResource extends Resource
{
    protected static ?string $model = PrintJob::class;

    public static function getNavigationIcon(): string { return 'heroicon-o-printer'; }
    public static function getNavigationGroup(): string { return 'Hardware'; }
    public static function getNavigationSort(): int { return 2; }
    public static function getModelLabel(): string { return 'Print Job'; }
    public static function getPluralModelLabel(): string { return 'Print Jobs'; }

    public static function form(Schema $schema): Schema
    {
        return $schema->components([]);
    }

    public static function infolist(Schema $schema): Schema
    {
        return $schema->components([
            Section::make('Rincian Cetak Foto')->schema([
                TextEntry::make('id')->label('Print Job ID'),
                TextEntry::make('session.id')->label('ID Sesi Foto'),
                TextEntry::make('session.event.name')->label('Event')->default('Main Booth'),
                TextEntry::make('printer')->label('Nama / Tipe Printer')->default('-'),
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
                TextColumn::make('id')->sortable(),
                TextColumn::make('session_id')->label('ID Sesi'),
                TextColumn::make('printer')->label('Printer'),
                TextColumn::make('status')->label('Status')->badge()
                    ->color(fn ($state) => match($state) {
                        'done'     => 'success',
                        'printing' => 'warning',
                        'failed'   => 'danger',
                        default    => 'gray',
                    }),
                TextColumn::make('printed_at')->label('Dicetak')->dateTime('d M Y H:i')->sortable(),
            ])
            ->defaultSort('id', 'desc')
            ->filters([
                SelectFilter::make('status')
                    ->options(['pending'=>'Pending','printing'=>'Printing','done'=>'Done','failed'=>'Failed']),
            ])
            ->actions([ViewAction::make()])
            ->poll('10s');
    }

    public static function getEloquentQuery(): \Illuminate\Database\Eloquent\Builder
    {
        $query = parent::getEloquentQuery();
        if ($cafeId = auth()->user()?->cafe_id) {
            $query->whereHas('session', fn ($sq) => 
                $sq->where('cafe_id', $cafeId)
                   ->orWhereHas('event', fn ($eq) => $eq->where('cafe_id', $cafeId))
            );
        }
        return $query;
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListPrintJobs::route('/'),
            'view'  => Pages\ViewPrintJob::route('/{record}'),
        ];
    }
}
