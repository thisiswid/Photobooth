// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'filter_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$filterListHash() => r'929d85389dbdf9044e69489fc4fe4ff38e03e596';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

abstract class _$FilterList
    extends BuildlessAutoDisposeAsyncNotifier<List<FilterModel>> {
  late final int eventId;

  FutureOr<List<FilterModel>> build(
    int eventId,
  );
}

/// See also [FilterList].
@ProviderFor(FilterList)
const filterListProvider = FilterListFamily();

/// See also [FilterList].
class FilterListFamily extends Family<AsyncValue<List<FilterModel>>> {
  /// See also [FilterList].
  const FilterListFamily();

  /// See also [FilterList].
  FilterListProvider call(
    int eventId,
  ) {
    return FilterListProvider(
      eventId,
    );
  }

  @override
  FilterListProvider getProviderOverride(
    covariant FilterListProvider provider,
  ) {
    return call(
      provider.eventId,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'filterListProvider';
}

/// See also [FilterList].
class FilterListProvider extends AutoDisposeAsyncNotifierProviderImpl<
    FilterList, List<FilterModel>> {
  /// See also [FilterList].
  FilterListProvider(
    int eventId,
  ) : this._internal(
          () => FilterList()..eventId = eventId,
          from: filterListProvider,
          name: r'filterListProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$filterListHash,
          dependencies: FilterListFamily._dependencies,
          allTransitiveDependencies:
              FilterListFamily._allTransitiveDependencies,
          eventId: eventId,
        );

  FilterListProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.eventId,
  }) : super.internal();

  final int eventId;

  @override
  FutureOr<List<FilterModel>> runNotifierBuild(
    covariant FilterList notifier,
  ) {
    return notifier.build(
      eventId,
    );
  }

  @override
  Override overrideWith(FilterList Function() create) {
    return ProviderOverride(
      origin: this,
      override: FilterListProvider._internal(
        () => create()..eventId = eventId,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        eventId: eventId,
      ),
    );
  }

  @override
  AutoDisposeAsyncNotifierProviderElement<FilterList, List<FilterModel>>
      createElement() {
    return _FilterListProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is FilterListProvider && other.eventId == eventId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, eventId.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin FilterListRef on AutoDisposeAsyncNotifierProviderRef<List<FilterModel>> {
  /// The parameter `eventId` of this provider.
  int get eventId;
}

class _FilterListProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<FilterList,
        List<FilterModel>> with FilterListRef {
  _FilterListProviderElement(super.provider);

  @override
  int get eventId => (origin as FilterListProvider).eventId;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
