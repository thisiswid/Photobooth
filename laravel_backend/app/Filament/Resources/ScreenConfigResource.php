<?php

namespace App\Filament\Resources;

use App\Filament\Resources\ScreenConfigResource\Pages;
use App\Models\ScreenConfig;
use Filament\Forms\Components\FileUpload;
use Filament\Forms\Components\Repeater;
use Filament\Forms\Components\Select;
use Filament\Forms\Components\Textarea;
use Filament\Forms\Components\TextInput;
use Filament\Forms\Components\Toggle;
use Filament\Schemas\Schema;
use Filament\Notifications\Notification;
use Filament\Resources\Resource;
use Filament\Actions\Action;
use Filament\Actions\BulkActionGroup;
use Filament\Actions\DeleteAction;
use Filament\Actions\DeleteBulkAction;
use Filament\Actions\EditAction;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Table;

class ScreenConfigResource extends Resource
{
    protected static ?string $model = ScreenConfig::class;

    public static function getNavigationIcon(): string { return 'heroicon-o-device-phone-mobile'; }
    public static function getNavigationGroup(): string { return 'Konten'; }
    public static function getNavigationSort(): int { return 4; }
    public static function getModelLabel(): string { return 'Screen Content'; }
    public static function getPluralModelLabel(): string { return 'Screen Contents'; }

    public static function form(Schema $schema): Schema
    {
        return $schema->components([
            Select::make('event_id')->label('Event')
                ->relationship('event', 'name')->searchable()->preload(),
            Select::make('screen_type')->label('Tipe Layar')
                ->options(['welcome' => 'Welcome', 'tutorial' => 'Tutorial'])
                ->required(),
            Select::make('status')->label('Status')
                ->options(['draft' => 'Draft', 'preview' => 'Preview', 'published' => 'Published', 'active' => 'Active'])
                ->default('draft')->required(),
            TextInput::make('title')->label('Judul')->maxLength(255),
            Textarea::make('description')->label('Deskripsi')->rows(3),
            FileUpload::make('background_url')->label('Background')->image()->directory('screens'),
            TextInput::make('button_text')->label('Teks Tombol')->maxLength(100),
            TextInput::make('version')->label('Versi')->numeric()->default(1),

            Repeater::make('tutorialSteps')->label('Tutorial Steps')
                ->relationship()
                ->schema([
                    TextInput::make('title')->label('Judul')->maxLength(255),
                    Textarea::make('description')->label('Deskripsi')->rows(2),
                    FileUpload::make('image_url')->label('Gambar')->image()->directory('tutorial-steps'),
                    TextInput::make('sort_order')->label('Urutan')->numeric()->default(0),
                    Toggle::make('active')->label('Aktif')->default(true),
                ])
                ->orderColumn('sort_order')
                ->columnSpanFull()
                ->visible(fn ($get) => $get('screen_type') === 'tutorial'),
        ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                TextColumn::make('screen_type')->label('Tipe')->badge()
                    ->color(fn ($state) => match($state) {
                        'welcome'  => 'info',
                        'tutorial' => 'warning',
                        default    => 'gray',
                    }),
                TextColumn::make('title')->label('Judul')->searchable(),
                TextColumn::make('event.name')->label('Event'),
                TextColumn::make('status')->label('Status')->badge()
                    ->color(fn ($state) => match($state) {
                        'active'    => 'success',
                        'published' => 'primary',
                        'preview'   => 'warning',
                        'draft'     => 'gray',
                        default     => 'gray',
                    }),
                TextColumn::make('version')->label('Versi'),
            ])
            ->actions([
                EditAction::make(),
                Action::make('preview')
                    ->label('Preview')->color('warning')
                    ->action(function ($record) {
                        $record->update(['status' => 'preview']);
                        Notification::make()->title('Status diubah ke Preview')->success()->send();
                    })
                    ->visible(fn ($record) => $record->status === 'draft'),
                Action::make('publish')
                    ->label('Publish')->color('success')
                    ->requiresConfirmation()
                    ->action(function ($record) {
                        ScreenConfig::where('screen_type', $record->screen_type)
                            ->where('event_id', $record->event_id)
                            ->where('status', 'active')
                            ->update(['status' => 'published']);
                        $record->update(['status' => 'active', 'version' => $record->version + 1]);
                        Notification::make()->title('Screen berhasil dipublish')->success()->send();
                    })
                    ->visible(fn ($record) => in_array($record->status, ['draft', 'preview'])),
                DeleteAction::make(),
            ])
            ->bulkActions([BulkActionGroup::make([DeleteBulkAction::make()])]);
    }

    public static function getPages(): array
    {
        return [
            'index'  => Pages\ListScreenConfigs::route('/'),
            'create' => Pages\CreateScreenConfig::route('/create'),
            'edit'   => Pages\EditScreenConfig::route('/{record}/edit'),
        ];
    }
}
