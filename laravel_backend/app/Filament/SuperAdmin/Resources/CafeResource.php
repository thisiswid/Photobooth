<?php

namespace App\Filament\SuperAdmin\Resources;

use App\Filament\SuperAdmin\Resources\CafeResource\Pages;
use App\Models\Cafe;
use Filament\Actions\DeleteAction;
use Filament\Actions\EditAction;
use Filament\Actions\ViewAction;
use Filament\Infolists\Components\ImageEntry;
use Filament\Infolists\Components\TextEntry;
use Filament\Forms\Components\DatePicker;
use Filament\Forms\Components\FileUpload;
use Filament\Forms\Components\Select;
use Filament\Forms\Components\Textarea;
use Filament\Forms\Components\TextInput;
use Filament\Resources\Resource;
use Filament\Schemas\Components\Section;
use Filament\Schemas\Schema;
use Filament\Tables\Columns\IconColumn;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Filters\SelectFilter;
use Filament\Tables\Table;
use Illuminate\Support\Str;

class CafeResource extends Resource
{
    protected static ?string $model = Cafe::class;

    public static function getNavigationIcon(): string { return 'heroicon-o-building-storefront'; }
    public static function getNavigationGroup(): string { return 'Tenant Management'; }
    public static function getNavigationSort(): int { return 1; }
    public static function getModelLabel(): string { return 'Cafe / Tenant'; }
    public static function getPluralModelLabel(): string { return 'Daftar Cafe / Tenant'; }

    public static function form(Schema $schema): Schema
    {
        return $schema->components([
            Section::make('Informasi Cafe / Tenant')
                ->schema([
                    TextInput::make('name')
                        ->label('Nama Cafe')
                        ->required()
                        ->live(onBlur: true)
                        ->afterStateUpdated(fn ($state, callable $set) => $set('slug', Str::slug($state))),
                    TextInput::make('slug')
                        ->label('Slug')
                        ->required()
                        ->unique(ignoreRecord: true),
                    TextInput::make('code')
                        ->label('Kode Lisensi / Identifier')
                        ->required()
                        ->default(fn () => 'PB-' . strtoupper(Str::random(6)))
                        ->unique(ignoreRecord: true),
                    Select::make('status')
                        ->label('Status Kemitraan')
                        ->options([
                            'active'    => 'Active (Beroperasi)',
                            'suspended' => 'Suspended (Ditangguhkan)',
                            'inactive'  => 'Inactive (Nonaktif)',
                        ])
                        ->default('active')
                        ->required(),
                ])->columns(2),

            Section::make('Kontak & PIC')
                ->schema([
                    TextInput::make('pic_name')->label('Nama PIC / Pemilik')->maxLength(255),
                    TextInput::make('pic_phone')->label('No. WhatsApp / HP')->tel()->maxLength(50),
                    TextInput::make('pic_email')->label('Email PIC')->email()->maxLength(255),
                    Textarea::make('address')->label('Alamat Lokasi Booth / Cafe')->columnSpanFull(),
                ])->columns(3),

            Section::make('Langganan & Bagi Hasil (Platform Revenue Share)')
                ->schema([
                    DatePicker::make('subscription_end_at')
                        ->label('Masa Aktif Langganan / Lisensi')
                        ->helperText('Biarkan kosong jika sistem beli putus / seumur hidup'),
                    TextInput::make('revenue_share_percentage')
                        ->label('Platform Fee / Revenue Share (%)')
                        ->numeric()
                        ->default(10.00)
                        ->suffix('%')
                        ->helperText('Persentase bagi hasil platform dari omset transaksi booth'),
                    FileUpload::make('logo_path')
                        ->label('Logo Cafe')
                        ->image()
                        ->directory('cafes/logos')
                        ->disk('public'),
                    Textarea::make('notes')
                        ->label('Catatan Internal Super Admin')
                        ->columnSpanFull(),
                ])->columns(2),
        ]);
    }

    public static function infolist(Schema $schema): Schema
    {
        return $schema->components([
            Section::make('Informasi Cafe / Tenant')->schema([
                TextEntry::make('name')->label('Nama Cafe')->weight('bold'),
                TextEntry::make('slug')->label('Slug'),
                TextEntry::make('code')->label('Kode Lisensi / Identifier')->badge()->color('info')->copyable(),
                TextEntry::make('status')->label('Status Kemitraan')->badge()
                    ->color(fn ($state) => match($state) {
                        'active'    => 'success',
                        'suspended' => 'warning',
                        default     => 'gray',
                    }),
                TextEntry::make('devices_count')->label('Jumlah Mesin Booth')
                    ->state(fn ($record) => $record->devices()->count() . ' Mesin'),
                TextEntry::make('created_at')->label('Bergabung Sejak')->dateTime('d M Y'),
            ])->columns(3),

            Section::make('Kontak & Lokasi PIC')->schema([
                TextEntry::make('pic_name')->label('Nama PIC')->default('-'),
                TextEntry::make('pic_phone')->label('WhatsApp / Telepon')->default('-'),
                TextEntry::make('pic_email')->label('Email PIC')->default('-'),
                TextEntry::make('address')->label('Alamat Lokasi')->default('-')->columnSpanFull(),
            ])->columns(3),

            Section::make('Langganan & Bagi Hasil (Revenue Share)')->schema([
                TextEntry::make('subscription_end_at')->label('Masa Aktif Lisensi')->dateTime('d M Y')->placeholder('Seumur Hidup / Permanen'),
                TextEntry::make('revenue_share_percentage')->label('Platform Fee / Revenue Share')->suffix('%'),
                ImageEntry::make('logo_path')->label('Logo Cafe')->disk('public')->placeholder('Belum ada logo'),
                TextEntry::make('notes')->label('Catatan Internal')->default('-')->columnSpanFull(),
            ])->columns(2),
        ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                TextColumn::make('name')
                    ->label('Nama Cafe')
                    ->searchable()
                    ->sortable()
                    ->description(fn (Cafe $record): string => $record->code ?? ''),
                TextColumn::make('pic_name')
                    ->label('PIC / Kontak')
                    ->description(fn (Cafe $record): string => $record->pic_phone ?? '-'),
                TextColumn::make('devices_count')
                    ->label('Mesin Booth')
                    ->counts('devices')
                    ->badge()
                    ->color('info')
                    ->sortable(),
                TextColumn::make('revenue_share_percentage')
                    ->label('Bagi Hasil')
                    ->suffix('%')
                    ->sortable(),
                TextColumn::make('status')
                    ->label('Status')
                    ->badge()
                    ->color(fn ($state) => match($state) {
                        'active'    => 'success',
                        'suspended' => 'warning',
                        default     => 'gray',
                    }),
                TextColumn::make('subscription_end_at')
                    ->label('Masa Aktif')
                    ->dateTime('d M Y')
                    ->placeholder('Seumur Hidup')
                    ->sortable(),
                TextColumn::make('created_at')
                    ->label('Bergabung')
                    ->dateTime('d M Y')
                    ->toggleable(isToggledHiddenByDefault: true),
            ])
            ->filters([
                SelectFilter::make('status')
                    ->options([
                        'active'    => 'Active',
                        'suspended' => 'Suspended',
                        'inactive'  => 'Inactive',
                    ]),
            ])
            ->actions([
                ViewAction::make(),
                EditAction::make(),
                DeleteAction::make(),
            ]);
    }

    public static function getPages(): array
    {
        return [
            'index'  => Pages\ListCafes::route('/'),
            'create' => Pages\CreateCafe::route('/create'),
            'edit'   => Pages\EditCafe::route('/{record}/edit'),
        ];
    }
}
