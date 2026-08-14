// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'frame_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$frameListHash() => r'3d28e3b84f2452c2e4f4d0367a4c0ea73e0f9e17';

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

abstract class _$FrameList
    extends BuildlessAutoDisposeAsyncNotifier<List<FrameModel>> {
  late final int eventId;

  FutureOr<List<FrameModel>> build(
    int eventId,
  );
}

/// See also [FrameList].
@ProviderFor(FrameList)
const frameListProvider = FrameListFamily();

/// See also [FrameList].
class FrameListFamily extends Family<AsyncValue<List<FrameModel>>> {
  /// See also [FrameList].
  const FrameListFamily();

  /// See also [FrameList].
  FrameListProvider call(
    int eventId,
  ) {
    return FrameListProvider(
      eventId,
    );
  }

  @override
  FrameListProvider getProviderOverride(
    covariant FrameListProvider provider,
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
  String? get name => r'frameListProvider';
}

/// See also [FrameList].
class FrameListProvider
    extends AutoDisposeAsyncNotifierProviderImpl<FrameList, List<FrameModel>> {
  /// See also [FrameList].
  FrameListProvider(
    int eventId,
  ) : this._internal(
          () => FrameList()..eventId = eventId,
          from: frameListProvider,
          name: r'frameListProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$frameListHash,
          dependencies: FrameListFamily._dependencies,
          allTransitiveDependencies: FrameListFamily._allTransitiveDependencies,
          eventId: eventId,
        );

  FrameListProvider._internal(
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
  FutureOr<List<FrameModel>> runNotifierBuild(
    covariant FrameList notifier,
  ) {
    return notifier.build(
      eventId,
    );
  }

  @override
  Override overrideWith(FrameList Function() create) {
    return ProviderOverride(
      origin: this,
      override: FrameListProvider._internal(
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
  AutoDisposeAsyncNotifierProviderElement<FrameList, List<FrameModel>>
      createElement() {
    return _FrameListProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is FrameListProvider && other.eventId == eventId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, eventId.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin FrameListRef on AutoDisposeAsyncNotifierProviderRef<List<FrameModel>> {
  /// The parameter `eventId` of this provider.
  int get eventId;
}

class _FrameListProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<FrameList, List<FrameModel>>
    with FrameListRef {
  _FrameListProviderElement(super.provider);

  @override
  int get eventId => (origin as FrameListProvider).eventId;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
