<?php

namespace App\Filament\Resources;

use App\Filament\Resources\VoucherResource\Pages;
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
use Illuminate\Database\Eloquent\Builder;

class VoucherResource extends Resource
{
    protected static ?string $model = Voucher::class;

    public static function getNavigationIcon(): string
    {
        return 'heroicon-o-ticket';
    }

    public static function getNavigationGroup(): string
    {
        return 'Keuangan';
    }

    public static function getNavigationSort(): int
    {
        return 2;
    }

    public static function getModelLabel(): string
    {
        return 'Voucher';
    }

    public static function getPluralModelLabel(): string
    {
        return 'Voucher & Promo';
    }

    public static function form(Schema $schema): Schema
    {
        return $schema->components([
            Section::make('Voucher Cafe')->description('Voucher ini hanya dapat digunakan pada aplikasi yang aktif untuk cafe Anda.')->schema([
                TextInput::make('name')->label('Nama Promo')->required()->maxLength(255),
                TextInput::make('code')->label('Kode Voucher')->maxLength(64)->unique(ignoreRecord: true)
                    ->default(fn () => Voucher::generateUniqueCode())
                    ->helperText('Kode dibuat otomatis oleh sistem, tetapi tetap bisa diubah.'),
                Select::make('type')->label('Jenis Diskon')->options([
                    'full' => 'Gratis Penuh',
                    'fixed' => 'Potongan Nominal',
                    'percentage' => 'Potongan Persen',
                ])->required()->default('fixed'),
                TextInput::make('value')->label('Nilai Diskon')->numeric()->minValue(0)->default(0)
                    ->helperText('Nominal Rupiah atau angka persen. Untuk Gratis Penuh isi 0.'),
                TextInput::make('max_discount')->label('Maksimal Diskon Persen')->numeric()->minValue(0)->prefix('Rp')
                    ->helperText('Opsional, hanya digunakan untuk tipe persen.'),
                TextInput::make('minimum_purchase')->label('Minimum Transaksi')->numeric()->minValue(0)->default(0)->prefix('Rp'),
                Select::make('event_id')->label('Khusus Event')->options(fn () => Event::where('cafe_id', auth()->user()?->cafe_id)->pluck('name', 'id'))
                    ->searchable()->placeholder('Semua event cafe'),
                TextInput::make('quota')->label('Kuota Total')->numeric()->minValue(1)->helperText('Kosong berarti tanpa batas.'),
                TextInput::make('per_device_limit')->label('Batas per Perangkat')->numeric()->minValue(1)
                    ->placeholder('Tanpa batas')
                    ->helperText('Sebaiknya dikosongkan untuk kiosk bersama. Isi hanya jika satu mesin memang perlu dibatasi.'),
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
            TextColumn::make('code')->label('Kode')->badge()->copyable()->searchable()->sortable(),
            TextColumn::make('name')->label('Promo')->searchable(),
            TextColumn::make('type')->label('Jenis')->badge()->formatStateUsing(fn ($state) => match ($state) {
                'full' => 'Gratis', 'fixed' => 'Nominal', 'percentage' => 'Persen', default => $state,
            }),
            TextColumn::make('value')->label('Nilai')->formatStateUsing(fn ($state, Voucher $record) => match ($record->type) {
                'full' => '100%', 'percentage' => $state.'%', default => 'Rp '.number_format((int) $state, 0, ',', '.'),
            }),
            TextColumn::make('usage')->label('Terpakai')->state(fn (Voucher $record) => $record->used_count.' / '.($record->quota ?? '∞')),
            TextColumn::make('expires_at')->label('Berakhir')->dateTime('d M Y H:i')->placeholder('Tanpa batas')->sortable(),
            IconColumn::make('is_active')->label('Aktif')->boolean(),
        ])->filters([
            SelectFilter::make('type')->options(['full' => 'Gratis', 'fixed' => 'Nominal', 'percentage' => 'Persen']),
        ])->actions([
            EditAction::make(),
            DeleteAction::make()->visible(fn (Voucher $record) => $record->redemptions()->doesntExist()),
        ])->defaultSort('created_at', 'desc');
    }

    public static function getEloquentQuery(): Builder
    {
        $query = parent::getEloquentQuery();

        return auth()->user()?->cafe_id ? $query->where('cafe_id', auth()->user()->cafe_id) : $query->whereRaw('1 = 0');
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListVouchers::route('/'),
            'create' => Pages\CreateVoucher::route('/create'),
            'edit' => Pages\EditVoucher::route('/{record}/edit'),
        ];
    }
}
