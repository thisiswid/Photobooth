<?php

namespace App\Filament\SuperAdmin\Resources;

use App\Filament\SuperAdmin\Resources\GlobalVoucherResource\Pages;
use App\Models\Cafe;
use App\Models\Event;
use App\Models\Voucher;
use Filament\Actions\DeleteAction;
use Filament\Actions\EditAction;
use Filament\Forms\Components\DateTimePicker;
use Filament\Forms\Components\Select;
use Filament\Forms\Components\Textarea;
use Filament\Forms\Components\TextInput;
use Filament\Forms\Components\Toggle;
use Filament\Resources\Resource;
use Filament\Schemas\Components\Section;
use Filament\Schemas\Schema;
use Filament\Tables\Columns\IconColumn;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Filters\SelectFilter;
use Filament\Tables\Table;

class GlobalVoucherResource extends Resource
{
    protected static ?string $model = Voucher::class;

    public static function getNavigationIcon(): string
    {
        return 'heroicon-o-ticket';
    }

    public static function getNavigationGroup(): string
    {
        return 'Finance & Analytics';
    }

    public static function getNavigationSort(): int
    {
        return 3;
    }

    public static function getModelLabel(): string
    {
        return 'Voucher Cafe';
    }

    public static function getPluralModelLabel(): string
    {
        return 'Semua Voucher Cafe';
    }

    public static function form(Schema $schema): Schema
    {
        return $schema->components([
            Section::make('Alokasi Tenant')->schema([
                Select::make('cafe_id')->label('Cafe / Tenant')->options(Cafe::pluck('name', 'id'))->searchable()->required()->live(),
                Select::make('event_id')->label('Khusus Event')->options(fn () => Event::with('cafe')->get()
                    ->mapWithKeys(fn (Event $event) => [$event->id => ($event->cafe?->name.' — '.$event->name)]))
                    ->searchable()->placeholder('Semua event cafe'),
            ])->columns(2),
            Section::make('Pengaturan Voucher')->schema([
                TextInput::make('name')->label('Nama Promo')->required()->maxLength(255),
                TextInput::make('code')->label('Kode Voucher')->maxLength(64)->unique(ignoreRecord: true)
                    ->default(fn () => Voucher::generateUniqueCode())
                    ->helperText('Kode dibuat otomatis oleh sistem, tetapi tetap bisa diubah.'),
                Select::make('type')->label('Jenis Diskon')->options([
                    'full' => 'Gratis Penuh', 'fixed' => 'Potongan Nominal', 'percentage' => 'Potongan Persen',
                ])->required()->default('fixed'),
                TextInput::make('value')->label('Nilai Diskon')->numeric()->minValue(0)->default(0)
                    ->helperText('Nominal Rupiah atau angka persen; Gratis Penuh menggunakan nilai 0.'),
                TextInput::make('max_discount')->label('Maksimal Diskon Persen')->numeric()->minValue(0)->prefix('Rp'),
                TextInput::make('minimum_purchase')->label('Minimum Transaksi')->numeric()->minValue(0)->default(0)->prefix('Rp'),
                TextInput::make('quota')->label('Kuota Total')->numeric()->minValue(1)->helperText('Kosong berarti tanpa batas.'),
                TextInput::make('per_device_limit')->label('Batas per Perangkat')->numeric()->minValue(1)
                    ->placeholder('Tanpa batas')
                    ->helperText('Kosongkan untuk kiosk bersama; kuota total tetap berlaku.'),
                DateTimePicker::make('starts_at')->label('Mulai Berlaku')->native(false),
                DateTimePicker::make('expires_at')->label('Berakhir')->native(false),
                Toggle::make('is_active')->label('Voucher Aktif')->default(true),
                Textarea::make('notes')->label('Catatan Internal')->rows(2)->columnSpanFull(),
            ])->columns(2),
        ]);
    }

    public static function table(Table $table): Table
    {
        return $table->columns([
            TextColumn::make('cafe.name')->label('Cafe')->badge()->searchable()->sortable(),
            TextColumn::make('code')->label('Kode')->badge()->copyable()->searchable(),
            TextColumn::make('name')->label('Promo')->searchable(),
            TextColumn::make('type')->label('Jenis')->badge(),
            TextColumn::make('usage')->label('Terpakai')->state(fn (Voucher $record) => $record->used_count.' / '.($record->quota ?? '∞')),
            TextColumn::make('expires_at')->label('Berakhir')->dateTime('d M Y H:i')->placeholder('Tanpa batas'),
            IconColumn::make('is_active')->label('Aktif')->boolean(),
        ])->filters([
            SelectFilter::make('cafe_id')->label('Cafe')->relationship('cafe', 'name'),
            SelectFilter::make('type')->options(['full' => 'Gratis', 'fixed' => 'Nominal', 'percentage' => 'Persen']),
        ])->actions([
            EditAction::make(),
            DeleteAction::make()->visible(fn (Voucher $record) => $record->redemptions()->doesntExist()),
        ])->defaultSort('created_at', 'desc');
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListGlobalVouchers::route('/'),
            'create' => Pages\CreateGlobalVoucher::route('/create'),
            'edit' => Pages\EditGlobalVoucher::route('/{record}/edit'),
        ];
    }
}
