// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$PhotoModelImpl _$$PhotoModelImplFromJson(Map<String, dynamic> json) =>
    _$PhotoModelImpl(
      id: json['id'] as String,
      sessionId: json['sessionId'] as String,
      fileUrl: json['fileUrl'] as String,
      type: $enumDecodeNullable(_$PhotoTypeEnumMap, json['type']) ??
          PhotoType.raw,
      capturedAt: json['capturedAt'] == null
          ? null
          : DateTime.parse(json['capturedAt'] as String),
      retakeCount: (json['retakeCount'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$$PhotoModelImplToJson(_$PhotoModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'sessionId': instance.sessionId,
      'fileUrl': instance.fileUrl,
      'type': _$PhotoTypeEnumMap[instance.type]!,
      'capturedAt': instance.capturedAt?.toIso8601String(),
      'retakeCount': instance.retakeCount,
    };

const _$PhotoTypeEnumMap = {
  PhotoType.raw: 'raw',
  PhotoType.final_: 'final',
};

_$SessionModelImpl _$$SessionModelImplFromJson(Map<String, dynamic> json) =>
    _$SessionModelImpl(
      sessionId: (json['sessionId'] as num).toInt(),
      eventId: (json['eventId'] as num).toInt(),
      status: json['status'] as String? ?? 'active',
      frameId: (json['frameId'] as num?)?.toInt(),
      poseCount: (json['poseCount'] as num?)?.toInt() ?? 1,
      filterId: (json['filterId'] as num?)?.toInt(),
      selectedFilter: json['selectedFilter'] as String?,
      retakeCount: (json['retakeCount'] as num?)?.toInt() ?? 0,
      startedAt: json['startedAt'] == null
          ? null
          : DateTime.parse(json['startedAt'] as String),
      expiresAt: json['expiresAt'] == null
          ? null
          : DateTime.parse(json['expiresAt'] as String),
      finishedAt: json['finishedAt'] == null
          ? null
          : DateTime.parse(json['finishedAt'] as String),
      photos: (json['photos'] as List<dynamic>?)
              ?.map((e) => PhotoModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      currentPoseIndex: (json['currentPoseIndex'] as num?)?.toInt() ?? 0,
      finalUrl: json['finalUrl'] as String?,
      gifUrl: json['gifUrl'] as String?,
      qrToken: json['qrToken'] as String?,
    );

Map<String, dynamic> _$$SessionModelImplToJson(_$SessionModelImpl instance) =>
    <String, dynamic>{
      'sessionId': instance.sessionId,
      'eventId': instance.eventId,
      'status': instance.status,
      'frameId': instance.frameId,
      'poseCount': instance.poseCount,
      'filterId': instance.filterId,
      'selectedFilter': instance.selectedFilter,
      'retakeCount': instance.retakeCount,
      'startedAt': instance.startedAt?.toIso8601String(),
      'expiresAt': instance.expiresAt?.toIso8601String(),
      'finishedAt': instance.finishedAt?.toIso8601String(),
      'photos': instance.photos,
      'currentPoseIndex': instance.currentPoseIndex,
      'finalUrl': instance.finalUrl,
      'gifUrl': instance.gifUrl,
      'qrToken': instance.qrToken,
    };
