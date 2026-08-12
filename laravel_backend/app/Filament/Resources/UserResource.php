<?php

namespace App\Filament\Resources;

use App\Filament\Resources\UserResource\Pages;
use App\Models\User;
use Filament\Forms\Components\Select;
use Filament\Forms\Components\TextInput;
use Filament\Schemas\Schema;
use Filament\Resources\Resource;
use Filament\Actions\DeleteAction;
use Filament\Actions\EditAction;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Table;
use Illuminate\Support\Facades\Hash;

class UserResource extends Resource
{
    protected static ?string $model = User::class;

    public static function getNavigationIcon(): string { return 'heroicon-o-users'; }
    public static function getNavigationGroup(): string { return 'Pengaturan'; }
    public static function getNavigationSort(): int { return 1; }
    public static function getModelLabel(): string { return 'Pengguna'; }
    public static function getPluralModelLabel(): string { return 'Pengguna'; }

    public static function form(Schema $schema): Schema
    {
        return $schema->components([
            TextInput::make('name')->label('Nama')->required()->maxLength(255),
            TextInput::make('email')->label('Email')->email()->required()->unique(ignoreRecord: true),
            Select::make('role')->label('Role')
                ->options(['admin' => 'Admin', 'operator' => 'Operator', 'viewer' => 'Viewer'])
                ->default('operator'),
            TextInput::make('password')->label('Password')
                ->password()
                ->dehydrateStateUsing(fn ($state) => Hash::make($state))
                ->dehydrated(fn ($state) => filled($state))
                ->required(fn (string $context) => $context === 'create'),
        ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                TextColumn::make('name')->label('Nama')->searchable()->sortable(),
                TextColumn::make('email')->label('Email')->searchable(),
                TextColumn::make('role')->label('Role')->badge()
                    ->color(fn ($state) => match($state) {
                        'admin'    => 'danger',
                        'operator' => 'warning',
                        default    => 'gray',
                    }),
                TextColumn::make('created_at')->label('Dibuat')->dateTime('d M Y')->sortable(),
            ])
            ->actions([EditAction::make(), DeleteAction::make()]);
    }

    public static function getPages(): array
    {
        return [
            'index'  => Pages\ListUsers::route('/'),
            'create' => Pages\CreateUser::route('/create'),
            'edit'   => Pages\EditUser::route('/{record}/edit'),
        ];
    }
}
