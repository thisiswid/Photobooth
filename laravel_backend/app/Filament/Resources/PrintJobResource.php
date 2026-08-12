<?php

namespace App\Filament\Resources;

use App\Filament\Resources\PrintJobResource\Pages;
use App\Models\PrintJob;
use Filament\Schemas\Schema;
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

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListPrintJobs::route('/'),
            'view'  => Pages\ViewPrintJob::route('/{record}'),
        ];
    }
}
