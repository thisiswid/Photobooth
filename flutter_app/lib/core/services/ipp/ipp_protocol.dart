import 'dart:convert';
import 'dart:typed_data';

/// Encoder & decoder protokol IPP (Internet Printing Protocol) — RFC 8010/8011.
///
/// Dipakai untuk mencetak SILENT ke Epson L8050 lewat jaringan (AirPrint /
/// Mopria / IPP Everywhere), TANPA Android PrintManager sehingga tidak ada
/// dialog print preview dan tidak butuh Accessibility Service.
///
/// Format satu request IPP:
/// ```
///   version-number   (2 byte)  → 0x02 0x00 untuk IPP/2.0
///   operation-id     (2 byte)
///   request-id       (4 byte)
///   [ delimiter-tag (1 byte) diikuti daftar atribut ] ...
///   end-of-attributes-tag (0x03)
///   <data dokumen>
/// ```
///
/// Format satu atribut:
/// ```
///   value-tag (1) | name-length (2) | name | value-length (2) | value
/// ```
/// Nilai tambahan untuk atribut yang sama ditulis dengan name-length = 0.

// ─── Delimiter tag ────────────────────────────────────────────────────────────
class IppDelimiter {
  static const int operationAttributes = 0x01;
  static const int jobAttributes = 0x02;
  static const int endOfAttributes = 0x03;
  static const int printerAttributes = 0x04;
  static const int unsupportedAttributes = 0x05;
}

// ─── Value tag ────────────────────────────────────────────────────────────────
class IppTag {
  static const int unsupported = 0x10;
  static const int unknown = 0x12;
  static const int noValue = 0x13;

  static const int integer = 0x21;
  static const int boolean = 0x22;
  static const int enumValue = 0x23;

  static const int octetString = 0x30;
  static const int dateTime = 0x31;
  static const int resolution = 0x32;
  static const int rangeOfInteger = 0x33;
  static const int begCollection = 0x34;
  static const int textWithLanguage = 0x35;
  static const int nameWithLanguage = 0x36;
  static const int endCollection = 0x37;

  static const int textWithoutLanguage = 0x41;
  static const int nameWithoutLanguage = 0x42;
  static const int keyword = 0x44;
  static const int uri = 0x45;
  static const int uriScheme = 0x46;
  static const int charset = 0x47;
  static const int naturalLanguage = 0x48;
  static const int mimeMediaType = 0x49;
  static const int memberAttrName = 0x4A;
}

// ─── Operation id ─────────────────────────────────────────────────────────────
class IppOperation {
  static const int printJob = 0x0002;
  static const int validateJob = 0x0004;
  static const int createJob = 0x0005;
  static const int sendDocument = 0x0006;
  static const int getJobAttributes = 0x0009;
  static const int getPrinterAttributes = 0x000B;
}

/// Satuan resolusi pada value-tag resolution.
class IppResolutionUnit {
  static const int dpi = 3;
  static const int dpcm = 4;
}

/// Nilai resolution IPP (xres, yres, unit).
class IppResolution {
  final int cross;
  final int feed;
  final int unit;

  const IppResolution(this.cross, this.feed, [this.unit = IppResolutionUnit.dpi]);

  @override
  String toString() => '${cross}x$feed${unit == IppResolutionUnit.dpi ? 'dpi' : 'dpcm'}';
}

/// Kumpulan atribut bernama untuk satu collection (dipakai `media-col`).
class IppCollection {
  /// name → (tag, value). Urutan dipertahankan.
  final Map<String, MapEntry<int, Object>> members;

  const IppCollection(this.members);
}

// ─── Encoder ──────────────────────────────────────────────────────────────────

class IppRequestBuilder {
  final BytesBuilder _b = BytesBuilder(copy: false);
  int? _currentGroup;

  IppRequestBuilder({
    required int operationId,
    required int requestId,
    int versionMajor = 2,
    int versionMinor = 0,
  }) {
    _b.addByte(versionMajor);
    _b.addByte(versionMinor);
    _addInt16(operationId);
    _addInt32(requestId);
  }

  void _addInt16(int v) {
    _b.addByte((v >> 8) & 0xFF);
    _b.addByte(v & 0xFF);
  }

  void _addInt32(int v) {
    _b.addByte((v >> 24) & 0xFF);
    _b.addByte((v >> 16) & 0xFF);
    _b.addByte((v >> 8) & 0xFF);
    _b.addByte(v & 0xFF);
  }

  void _addLengthPrefixed(List<int> bytes) {
    _addInt16(bytes.length);
    _b.add(bytes);
  }

  /// Mulai grup atribut baru (operation-attributes / job-attributes / dst).
  void startGroup(int delimiter) {
    _b.addByte(delimiter);
    _currentGroup = delimiter;
  }

  /// Atribut bernilai teks (keyword, uri, charset, name, mimeMediaType, ...).
  void addString(int tag, String name, String value) {
    _b.addByte(tag);
    _addLengthPrefixed(utf8.encode(name));
    _addLengthPrefixed(utf8.encode(value));
  }

  /// Atribut teks bernilai jamak (nilai ke-2 dst ditulis dengan name-length 0).
  void addStrings(int tag, String name, List<String> values) {
    if (values.isEmpty) return;
    addString(tag, name, values.first);
    for (final v in values.skip(1)) {
      _b.addByte(tag);
      _addInt16(0); // name-length 0 = lanjutan atribut sebelumnya
      _addLengthPrefixed(utf8.encode(v));
    }
  }

  void addInteger(int tag, String name, int value) {
    _b.addByte(tag);
    _addLengthPrefixed(utf8.encode(name));
    _addInt16(4);
    _addInt32(value);
  }

  void addBoolean(String name, bool value) {
    _b.addByte(IppTag.boolean);
    _addLengthPrefixed(utf8.encode(name));
    _addInt16(1);
    _b.addByte(value ? 1 : 0);
  }

  void addResolution(String name, IppResolution res) {
    _b.addByte(IppTag.resolution);
    _addLengthPrefixed(utf8.encode(name));
    _addInt16(9);
    _addInt32(res.cross);
    _addInt32(res.feed);
    _b.addByte(res.unit);
  }

  /// Encode collection (RFC 3382) — dipakai untuk `media-col`, penting agar
  /// margin nol (borderless) bisa diminta secara eksplisit.
  ///
  /// Mendukung collection BERSARANG, yang wajib karena `media-col` berisi
  /// `media-size` yang juga sebuah collection:
  /// ```
  ///   begCollection  name="media-col"  value=""
  ///     memberAttrName name=""  value="media-size"
  ///     begCollection  name=""  value=""
  ///       memberAttrName name="" value="x-dimension"
  ///       integer        name="" value=10160
  ///       ...
  ///     endCollection  name=""  value=""
  ///     memberAttrName name=""  value="media-top-margin"
  ///     integer        name=""  value=0
  ///   endCollection
  /// ```
  void addCollection(String name, IppCollection col) {
    // begCollection pembuka: hanya yang terluar yang membawa nama atribut.
    _b.addByte(IppTag.begCollection);
    _addLengthPrefixed(utf8.encode(name));
    _addInt16(0);

    _writeCollectionMembers(col);

    _b.addByte(IppTag.endCollection);
    _addInt16(0);
    _addInt16(0);
  }

  void _writeCollectionMembers(IppCollection col) {
    col.members.forEach((memberName, entry) {
      // memberAttrName: name kosong, value = nama member
      _b.addByte(IppTag.memberAttrName);
      _addInt16(0);
      _addLengthPrefixed(utf8.encode(memberName));

      final tag = entry.key;
      final value = entry.value;

      if (value is IppCollection) {
        // Collection bersarang: begCollection tanpa nama, lalu rekursi.
        _b.addByte(IppTag.begCollection);
        _addInt16(0);
        _addInt16(0);

        _writeCollectionMembers(value);

        _b.addByte(IppTag.endCollection);
        _addInt16(0);
        _addInt16(0);
        return;
      }

      _b.addByte(tag);
      _addInt16(0); // member value selalu name-length 0
      if (value is int) {
        _addInt16(4);
        _addInt32(value);
      } else if (value is bool) {
        _addInt16(1);
        _b.addByte(value ? 1 : 0);
      } else if (value is IppResolution) {
        _addInt16(9);
        _addInt32(value.cross);
        _addInt32(value.feed);
        _b.addByte(value.unit);
      } else {
        _addLengthPrefixed(utf8.encode(value.toString()));
      }
    });
  }

  /// Tutup daftar atribut, lalu opsional lampirkan data dokumen.
  Uint8List finish([List<int>? documentData]) {
    _b.addByte(IppDelimiter.endOfAttributes);
    if (documentData != null && documentData.isNotEmpty) {
      _b.add(documentData);
    }
    _currentGroup = null;
    return _b.toBytes();
  }

  int? get currentGroup => _currentGroup;
}

// ─── Decoder ──────────────────────────────────────────────────────────────────

/// Hasil parsing satu response IPP.
class IppResponse {
  final int versionMajor;
  final int versionMinor;
  final int statusCode;
  final int requestId;

  /// Atribut gabungan dari semua grup: nama → daftar nilai.
  final Map<String, List<Object>> attributes;

  const IppResponse({
    required this.versionMajor,
    required this.versionMinor,
    required this.statusCode,
    required this.requestId,
    required this.attributes,
  });

  /// status-code < 0x0100 berarti sukses (termasuk ok-ignored / ok-conflicting).
  bool get isSuccess => statusCode < 0x0100;

  String get statusLabel => ippStatusLabel(statusCode);

  /// Ambil nilai pertama sebuah atribut sebagai String, atau null.
  String? firstString(String name) {
    final v = attributes[name];
    if (v == null || v.isEmpty) return null;
    return v.first.toString();
  }

  /// Ambil nilai pertama sebuah atribut sebagai int, atau null.
  int? firstInt(String name) {
    final v = attributes[name];
    if (v == null || v.isEmpty) return null;
    final f = v.first;
    if (f is int) return f;
    return int.tryParse(f.toString());
  }

  /// Ambil seluruh nilai sebuah atribut sebagai daftar String.
  List<String> stringList(String name) =>
      (attributes[name] ?? const []).map((e) => e.toString()).toList();
}

/// Terjemahan status-code IPP yang umum ditemui.
String ippStatusLabel(int code) {
  switch (code) {
    case 0x0000:
      return 'successful-ok';
    case 0x0001:
      return 'successful-ok-ignored-or-substituted-attributes';
    case 0x0002:
      return 'successful-ok-conflicting-attributes';
    case 0x0400:
      return 'client-error-bad-request';
    case 0x0401:
      return 'client-error-forbidden';
    case 0x0402:
      return 'client-error-not-authenticated';
    case 0x0403:
      return 'client-error-not-authorized';
    case 0x0404:
      return 'client-error-not-possible';
    case 0x0405:
      return 'client-error-timeout';
    case 0x0406:
      return 'client-error-not-found';
    case 0x0407:
      return 'client-error-gone';
    case 0x0408:
      return 'client-error-request-entity-too-large';
    case 0x0409:
      return 'client-error-request-value-too-long';
    case 0x040A:
      return 'client-error-document-format-not-supported';
    case 0x040B:
      return 'client-error-attributes-or-values-not-supported';
    case 0x040C:
      return 'client-error-uri-scheme-not-supported';
    case 0x040D:
      return 'client-error-charset-not-supported';
    case 0x040E:
      return 'client-error-conflicting-attributes';
    case 0x040F:
      return 'client-error-compression-not-supported';
    case 0x0410:
      return 'client-error-compression-error';
    case 0x0411:
      return 'client-error-document-format-error';
    case 0x0412:
      return 'client-error-document-access-error';
    case 0x0500:
      return 'server-error-internal-error';
    case 0x0501:
      return 'server-error-operation-not-supported';
    case 0x0502:
      return 'server-error-service-unavailable';
    case 0x0503:
      return 'server-error-version-not-supported';
    case 0x0504:
      return 'server-error-device-error';
    case 0x0505:
      return 'server-error-temporary-error';
    case 0x0506:
      return 'server-error-not-accepting-jobs';
    case 0x0507:
      return 'server-error-busy';
    case 0x0508:
      return 'server-error-job-canceled';
    case 0x0509:
      return 'server-error-multiple-document-jobs-not-supported';
    default:
      return 'unknown-status-0x${code.toRadixString(16).padLeft(4, '0')}';
  }
}

/// Parse byte response IPP. Melempar [FormatException] bila terlalu pendek.
IppResponse parseIppResponse(Uint8List data) {
  if (data.length < 8) {
    throw const FormatException('Response IPP terlalu pendek (< 8 byte)');
  }

  final bd = ByteData.sublistView(data);
  final versionMajor = data[0];
  final versionMinor = data[1];
  final statusCode = bd.getUint16(2);
  final requestId = bd.getUint32(4);

  final attributes = <String, List<Object>>{};
  String? lastName;
  var offset = 8;

  // Konteks collection: saat di dalam begCollection, member di-prefix nama collection.
  String? collectionName;
  String? pendingMemberName;

  while (offset < data.length) {
    final tag = data[offset];
    offset += 1;

    if (tag == IppDelimiter.endOfAttributes) break;

    // Delimiter grup: reset konteks nama.
    if (tag <= 0x05) {
      lastName = null;
      continue;
    }

    if (offset + 2 > data.length) break;
    final nameLen = bd.getUint16(offset);
    offset += 2;
    if (offset + nameLen > data.length) break;
    final name = nameLen > 0 ? utf8.decode(data.sublist(offset, offset + nameLen), allowMalformed: true) : null;
    offset += nameLen;

    if (offset + 2 > data.length) break;
    final valueLen = bd.getUint16(offset);
    offset += 2;
    if (offset + valueLen > data.length) break;
    final raw = data.sublist(offset, offset + valueLen);
    offset += valueLen;

    // ── Penanganan collection ──
    if (tag == IppTag.begCollection) {
      collectionName = name ?? lastName ?? 'collection';
      lastName = collectionName;
      continue;
    }
    if (tag == IppTag.endCollection) {
      collectionName = null;
      pendingMemberName = null;
      continue;
    }
    if (tag == IppTag.memberAttrName) {
      pendingMemberName = utf8.decode(raw, allowMalformed: true);
      continue;
    }

    final Object value;
    switch (tag) {
      case IppTag.integer:
      case IppTag.enumValue:
        value = valueLen >= 4 ? ByteData.sublistView(raw).getInt32(0) : 0;
        break;
      case IppTag.boolean:
        value = valueLen >= 1 && raw[0] == 1;
        break;
      case IppTag.resolution:
        if (valueLen >= 9) {
          final r = ByteData.sublistView(raw);
          value = IppResolution(r.getInt32(0), r.getInt32(4), raw[8]).toString();
        } else {
          value = '';
        }
        break;
      case IppTag.rangeOfInteger:
        if (valueLen >= 8) {
          final r = ByteData.sublistView(raw);
          value = '${r.getInt32(0)}-${r.getInt32(4)}';
        } else {
          value = '';
        }
        break;
      case IppTag.noValue:
      case IppTag.unknown:
      case IppTag.unsupported:
        value = '';
        break;
      default:
        value = utf8.decode(raw, allowMalformed: true);
    }

    // Tentukan kunci penyimpanan.
    String key;
    if (collectionName != null && pendingMemberName != null) {
      key = '$collectionName/$pendingMemberName';
      pendingMemberName = null;
    } else if (name != null && name.isNotEmpty) {
      key = name;
      lastName = name;
    } else if (lastName != null) {
      key = lastName; // nilai tambahan dari atribut sebelumnya
    } else {
      continue;
    }

    attributes.putIfAbsent(key, () => <Object>[]).add(value);
  }

  return IppResponse(
    versionMajor: versionMajor,
    versionMinor: versionMinor,
    statusCode: statusCode,
    requestId: requestId,
    attributes: attributes,
  );
}
