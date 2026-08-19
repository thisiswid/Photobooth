<?php

namespace App\Filament\SuperAdmin\Resources;

use App\Filament\SuperAdmin\Resources\PlatformUserResource\Pages;
use App\Models\User;
use Filament\Actions\DeleteAction;
use Filament\Actions\EditAction;
use Filament\Forms\Components\Select;
use Filament\Forms\Components\TextInput;
use Filament\Resources\Resource;
use Filament\Schemas\Components\Section;
use Filament\Schemas\Schema;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Filters\SelectFilter;
use Filament\Tables\Table;
use Illuminate\Support\Facades\Hash;

class PlatformUserResource extends Resource
{
    protected static ?string $model = User::class;

    public static function getNavigationIcon(): string { return 'heroicon-o-users'; }
    public static function getNavigationGroup(): string { return 'User & Access'; }
    public static function getNavigationSort(): int { return 4; }
    public static function getModelLabel(): string { return 'Akun Pengguna'; }
    public static function getPluralModelLabel(): string { return 'Semua Akun Pengguna'; }

    public static function form(Schema $schema): Schema
    {
        return $schema->components([
            Section::make('Informasi Akun & Hak Akses')
                ->schema([
                    TextInput::make('name')
                        ->label('Nama Lengkap')
                        ->required()
                        ->maxLength(255),
                    TextInput::make('email')
                        ->label('Email Login')
                        ->email()
                        ->required()
                        ->unique(ignoreRecord: true),
                    Select::make('role')
                        ->label('Peran / Hak Akses')
                        ->options([
                            'super_admin' => '👑 Super Admin (Platform Owner)',
                            'admin'       => '🏢 Cafe Admin (Pengelola Cafe)',
                            'operator'    => '👤 Operator / Kasir',
                            'viewer'      => '👁️ Viewer (Hanya Lihat)',
                        ])
                        ->required()
                        ->live(),
                    Select::make('cafe_id')
                        ->label('Asal Cafe / Tenant')
                        ->relationship('cafe', 'name')
                        ->searchable()
                        ->preload()
                        ->visible(fn (callable $get) => $get('role') !== 'super_admin')
                        ->required(fn (callable $get) => $get('role') !== 'super_admin')
                        ->helperText('Super admin tidak terikat dengan cafe tertentu'),
                    TextInput::make('password')
                        ->label('Password')
                        ->password()
                        ->dehydrateStateUsing(fn ($state) => Hash::make($state))
                        ->dehydrated(fn ($state) => filled($state))
                        ->required(fn (string $context) => $context === 'create'),
                ])->columns(2),
        ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                TextColumn::make('name')
                    ->label('Nama')
                    ->searchable()
                    ->sortable(),
                TextColumn::make('email')
                    ->label('Email')
                    ->searchable()
                    ->copyable(),
                TextColumn::make('role')
                    ->label('Role')
                    ->badge()
                    ->color(fn ($state) => match($state) {
                        'super_admin' => 'primary',
                        'admin'       => 'danger',
                        'operator'    => 'warning',
                        default       => 'gray',
                    })
                    ->formatStateUsing(fn ($state) => match($state) {
                        'super_admin' => 'Super Admin',
                        'admin'       => 'Cafe Admin',
                        'operator'    => 'Operator',
                        default       => 'Viewer',
                    }),
                TextColumn::make('cafe.name')
                    ->label('Cafe Tenant')
                    ->badge()
                    ->color('info')
                    ->placeholder('Platform Owner'),
                TextColumn::make('created_at')
                    ->label('Dibuat')
                    ->dateTime('d M Y')
                    ->sortable(),
            ])
            ->filters([
                SelectFilter::make('role')
                    ->options([
                        'super_admin' => 'Super Admin',
                        'admin'       => 'Cafe Admin',
                        'operator'    => 'Operator',
                    ]),
                SelectFilter::make('cafe_id')
                    ->label('Filter Cafe')
                    ->relationship('cafe', 'name'),
            ])
            ->actions([
                EditAction::make(),
                DeleteAction::make(),
            ]);
    }

    public static function getPages(): array
    {
        return [
            'index'  => Pages\ListPlatformUsers::route('/'),
            'create' => Pages\CreatePlatformUser::route('/create'),
            'edit'   => Pages\EditPlatformUser::route('/{record}/edit'),
        ];
    }
}
