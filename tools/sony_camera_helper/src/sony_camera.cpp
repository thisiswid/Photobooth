#include "sony_camera.h"

#include <windows.h>

#include <chrono>
#include <cstdio>
#include <cstring>
#include <sstream>
#include <thread>

namespace stb {
namespace {

using Clock = std::chrono::steady_clock;

int ElapsedMs(Clock::time_point from) {
  return static_cast<int>(
      std::chrono::duration_cast<std::chrono::milliseconds>(Clock::now() - from)
          .count());
}

// Pembaca little-endian dengan pemeriksaan batas.
class Reader {
 public:
  Reader(const BYTE* data, size_t size) : data_(data), size_(size) {}

  bool ok() const { return ok_; }
  size_t offset() const { return offset_; }

  bool Skip(size_t n) {
    if (!ok_ || offset_ + n > size_) return Fail();
    offset_ += n;
    return true;
  }

  template <typename T>
  bool Read(T* out) {
    if (!ok_ || offset_ + sizeof(T) > size_) return Fail();
    T value = 0;
    memcpy(&value, data_ + offset_, sizeof(T));
    offset_ += sizeof(T);
    *out = value;
    return true;
  }

  // Baca nilai berukuran size_bytes (1/2/4/8) ke uint64.
  bool ReadSized(size_t size_bytes, uint64_t* out) {
    if (size_bytes == 0) {
      *out = 0;
      return ok_;
    }
    if (!ok_ || size_bytes > 8 || offset_ + size_bytes > size_) return Fail();
    uint64_t value = 0;
    memcpy(&value, data_ + offset_, size_bytes);
    offset_ += size_bytes;
    *out = value;
    return true;
  }

 private:
  bool Fail() {
    ok_ = false;
    return false;
  }
  const BYTE* data_;
  size_t size_;
  size_t offset_ = 0;
  bool ok_ = true;
};

// Ukuran satu elemen untuk datatype PTP. 0 = panjang variabel.
size_t SizeOfDataType(uint16_t data_type) {
  switch (data_type) {
    case 0x0001:  // INT8
    case 0x0002:  // UINT8
      return 1;
    case 0x0003:  // INT16
    case 0x0004:  // UINT16
      return 2;
    case 0x0005:  // INT32
    case 0x0006:  // UINT32
      return 4;
    case 0x0007:  // INT64
    case 0x0008:  // UINT64
      return 8;
    default:
      return 0;
  }
}

// Lewati satu array PTP: UINT32 jumlah elemen, lalu elemen-elemennya.
bool SkipArrayOf(Reader* r, size_t element_size) {
  uint32_t count = 0;
  if (!r->Read(&count)) return false;
  return r->Skip(static_cast<size_t>(count) * element_size);
}

// Lewati satu nilai string PTP: UINT8 jumlah karakter, lalu UTF-16LE.
bool SkipPtpString(Reader* r) {
  uint8_t num_chars = 0;
  if (!r->Read(&num_chars)) return false;
  return r->Skip(static_cast<size_t>(num_chars) * sizeof(wchar_t));
}

size_t ArrayElementSize(uint16_t data_type) {
  switch (data_type) {
    case 0x4001:
    case 0x4002:
      return 1;
    case 0x4003:
    case 0x4004:
      return 2;
    case 0x4005:
    case 0x4006:
      return 4;
    case 0x4007:
    case 0x4008:
      return 8;
    default:
      return 0;
  }
}

// Baca dimensi langsung dari penanda SOF berkas JPEG.
// Kamera melaporkan ImagePixWidth/Height = 0 untuk objek buffer 0xFFFFC001,
// jadi satu-satunya sumber yang jujur adalah berkasnya sendiri.
bool ParseJpegDimensions(const std::vector<BYTE>& data, uint32_t* width,
                         uint32_t* height) {
  if (data.size() < 4 || data[0] != 0xFF || data[1] != 0xD8) return false;
  size_t i = 2;
  while (i + 3 < data.size()) {
    if (data[i] != 0xFF) {
      ++i;  // isian antar segmen
      continue;
    }
    const BYTE marker = data[i + 1];
    if (marker == 0xFF) {
      ++i;
      continue;
    }
    // Penanda tanpa payload.
    if (marker == 0x01 || (marker >= 0xD0 && marker <= 0xD9)) {
      i += 2;
      continue;
    }
    if (i + 3 >= data.size()) return false;
    const size_t seg_len =
        (static_cast<size_t>(data[i + 2]) << 8) | data[i + 3];
    if (seg_len < 2) return false;

    const bool is_sof = (marker >= 0xC0 && marker <= 0xCF) && marker != 0xC4 &&
                        marker != 0xC8 && marker != 0xCC;
    if (is_sof) {
      // payload: precision(1), height(2 BE), width(2 BE), components(1)
      const size_t p = i + 4;
      if (p + 5 > data.size()) return false;
      *height = (static_cast<uint32_t>(data[p + 1]) << 8) | data[p + 2];
      *width = (static_cast<uint32_t>(data[p + 3]) << 8) | data[p + 4];
      return *width > 0 && *height > 0;
    }
    if (marker == 0xDA) return false;  // mulai data terkompresi
    i += 2 + seg_len;
  }
  return false;
}

std::string Utf16ToUtf8(const wchar_t* text, int chars) {
  if (chars <= 0) return std::string();
  int needed = WideCharToMultiByte(CP_UTF8, 0, text, chars, nullptr, 0, nullptr,
                                   nullptr);
  if (needed <= 0) return std::string();
  std::string out(static_cast<size_t>(needed), '\0');
  WideCharToMultiByte(CP_UTF8, 0, text, chars, &out[0], needed, nullptr,
                      nullptr);
  return out;
}

}  // namespace

const char* PtpResponseName(uint16_t code) {
  switch (code) {
    case 0x2001: return "OK";
    case 0x2002: return "General_Error";
    case 0x2003:
      return "Session_Not_Open (sesi PTP driver sudah tertutup - cabut lalu "
             "colok ulang kamera)";
    case 0x2004: return "Invalid_TransactionID";
    case 0x2005: return "Operation_Not_Supported";
    case 0x2006: return "Parameter_Not_Supported";
    case 0x2007: return "Incomplete_Transfer";
    case 0x2008: return "Invalid_StorageID";
    case 0x2009: return "Invalid_ObjectHandle";
    case 0x200A: return "DeviceProp_Not_Supported";
    case 0x200D: return "Store_Full";
    case 0x2013: return "Store_Not_Available";
    case 0x2019: return "Device_Busy";
    case 0x201E: return "Invalid_Parameter";
    case 0x201F: return "Session_Already_Open";
    default: return "unknown";
  }
}

const char* AfStatusLabel(uint64_t value) {
  switch (value) {
    case kAfUnlock: return "unlock";
    case kAfSFocused: return "afs_focused";
    case kAfSNotFocused: return "afs_not_focused";
    case kAfCTracking: return "afc_tracking";
    case kAfCFocused: return "afc_focused";
    case kAfCNotFocused: return "afc_not_focused";
    case 0x08: return "unpause";
    case 0x09: return "pause";
    default: return "unknown";
  }
}

bool AfStatusIsFocused(uint64_t value) {
  return value == kAfSFocused || value == kAfCFocused;
}

bool AfStatusIsFailed(uint64_t value) {
  return value == kAfSNotFocused || value == kAfCNotFocused;
}

bool SonyCamera::Connect(const std::wstring& device_id,
                         const std::wstring& name_filter,
                         std::string* error_code, std::string* detail) {
  Disconnect();

  if (!transport_.Open(device_id, name_filter, detail)) {
    *error_code = "no_camera";
    return false;
  }

  // Urutan connect sesuai Camera Control PTP Reference:
  //   SDIO_Connect(1) -> SDIO_Connect(2) -> SDIO_GetExtDeviceInfo -> SDIO_Connect(3)
  auto sdio_connect = [&](DWORD phase, std::string* err) -> bool {
    DWORD params[3] = {phase, kSdioConnectId, kSdioConnectId};
    EscapeResult res;
    if (!transport_.Escape(kOcSdioConnect, params, 3, kNextPhaseReadData,
                           nullptr, 0, 0x08, &res, err)) {
      return false;
    }
    if (!res.ok()) {
      std::ostringstream os;
      os << "SDIO_Connect(" << phase << ") response=0x" << std::hex
         << res.responseCode << " (" << PtpResponseName(res.responseCode)
         << ")";
      *err = os.str();
      return false;
    }
    return true;
  };

  if (!sdio_connect(1, detail)) {
    *error_code = "connect_failed";
    transport_.Close();
    return false;
  }
  if (!sdio_connect(2, detail)) {
    *error_code = "connect_failed";
    transport_.Close();
    return false;
  }

  {
    DWORD params[1] = {kSdiExtensionVersion};
    EscapeResult res;
    if (!transport_.Escape(kOcSdioGetExtDeviceInfo, params, 1,
                           kNextPhaseReadData, nullptr, 0, 0x1000, &res,
                           detail) ||
        !res.ok()) {
      if (detail->empty()) *detail = "SDIO_GetExtDeviceInfo ditolak kamera";
      *error_code = "connect_failed";
      transport_.Close();
      return false;
    }
  }

  if (!sdio_connect(3, detail)) {
    *error_code = "connect_failed";
    transport_.Close();
    return false;
  }

  connected_ = true;

  // Beri tahu kamera bahwa host adalah PC (Position Key).
  uint8_t host_pc = 0x01;
  DWORD params[1] = {kDpcPositionKey};
  EscapeResult res;
  std::string ignored;
  transport_.Escape(kOcSdioSetExtDevicePropValue, params, 1,
                    kNextPhaseWriteData, &host_pc, sizeof(host_pc), 0, &res,
                    &ignored);

  if (!RefreshProperties(detail)) {
    *error_code = "connect_failed";
    Disconnect();
    return false;
  }

  detail->clear();
  return true;
}

void SonyCamera::Disconnect() {
  if (connected_) {
    // Lepaskan setengah-tekan supaya kamera tidak ditinggal dalam keadaan S1.
    std::string ignored;
    ControlDevice(kDpcS1Button, kButtonUp, &ignored);
    s1_held_ = false;
  }
  // SENGAJA TIDAK mengirim CloseSession (0x1003).
  //
  // Sesi PTP-nya bukan milik kita: yang membukanya adalah driver WIA/WPD
  // Windows, dan kita menumpang lewat IWiaItemExtras::Escape. Menutup sesi itu
  // membuat driver mengira sesinya masih hidup padahal kamera sudah menutupnya,
  // sehingga sambungan BERIKUTNYA gagal dengan Session_Not_Open (0x2003) dan
  // baru pulih setelah kamera dicabut-colok. Terbukti di perangkat 2026-09-02.
  //
  // Contoh Sony memanggil CloseSession, tetapi hanya sekali saat aplikasinya
  // ditutup total. Helper ini connect/disconnect berkali-kali sepanjang hari,
  // jadi pola itu tidak berlaku di sini. Melepas handle WIA sudah cukup.
  connected_ = false;
  props_.clear();
  transport_.Close();
}

bool SonyCamera::RefreshProperties(std::string* detail) {
  EscapeResult res;
  if (!transport_.Escape(kOcSdioGetAllExtDevicePropInfo, nullptr, 0,
                         kNextPhaseReadData, nullptr, 0, 128 * 1024, &res,
                         detail)) {
    return false;
  }
  if (!res.ok()) {
    std::ostringstream os;
    os << "SDIO_GetAllExtDevicePropInfo response=0x" << std::hex << res.responseCode
       << " (" << PtpResponseName(res.responseCode) << ")";
    *detail = os.str();
    return false;
  }
  return ParsePropertyDataset(res.data, detail);
}

bool SonyCamera::ParsePropertyDataset(const std::vector<BYTE>& data,
                                      std::string* detail) {
  if (data.size() < sizeof(uint64_t)) {
    *detail = "dataset properti terlalu pendek";
    return false;
  }
  Reader r(data.data(), data.size());
  uint64_t count = 0;
  if (!r.Read(&count)) {
    *detail = "gagal membaca jumlah properti";
    return false;
  }
  if (count > 4096) {
    *detail = "jumlah properti tidak masuk akal";
    return false;
  }

  std::map<uint16_t, DeviceProperty> parsed;
  for (uint64_t i = 0; i < count; ++i) {
    DeviceProperty prop;
    if (!r.Read(&prop.code) || !r.Read(&prop.data_type) ||
        !r.Read(&prop.get_set) || !r.Read(&prop.is_enabled)) {
      break;
    }

    const size_t scalar = SizeOfDataType(prop.data_type);
    if (scalar > 0) {
      uint64_t default_value = 0;
      if (!r.ReadSized(scalar, &default_value)) break;
      if (!r.ReadSized(scalar, &prop.current_value)) break;
    } else if (prop.data_type == 0xFFFF) {
      // STR: nilai default lalu nilai sekarang.
      if (!SkipPtpString(&r)) break;
      if (!SkipPtpString(&r)) break;
    } else {
      const size_t elem = ArrayElementSize(prop.data_type);
      if (elem == 0) break;
      if (!SkipArrayOf(&r, elem)) break;
      if (!SkipArrayOf(&r, elem)) break;
    }

    uint8_t form_flag = 0;
    if (!r.Read(&form_flag)) break;

    if (form_flag == 0x01) {
      // Range: min, max, step.
      if (!r.Skip(scalar * 3)) break;
    } else if (form_flag == 0x02) {
      // Enumeration: daftar nilai didukung lalu daftar nilai bisa diset.
      uint16_t num = 0;
      if (!r.Read(&num)) break;
      if (!r.Skip(static_cast<size_t>(num) * scalar)) break;
      if (!r.Read(&num)) break;
      if (!r.Skip(static_cast<size_t>(num) * scalar)) break;
    }

    parsed[prop.code] = prop;
    if (!r.ok()) break;
  }

  if (parsed.empty()) {
    *detail = "tidak ada properti yang berhasil diurai";
    return false;
  }
  props_.swap(parsed);
  return true;
}

bool SonyCamera::GetProperty(uint16_t code, DeviceProperty* out) const {
  auto it = props_.find(code);
  if (it == props_.end()) return false;
  *out = it->second;
  return true;
}

uint64_t SonyCamera::PropertyValue(uint16_t code, uint64_t fallback) const {
  auto it = props_.find(code);
  return it == props_.end() ? fallback : it->second.current_value;
}

bool SonyCamera::ControlDevice(uint16_t control_code, uint32_t value,
                               std::string* detail) {
  DWORD params[1] = {control_code};
  EscapeResult res;
  if (!transport_.Escape(kOcSdioControlDevice, params, 1, kNextPhaseWriteData,
                         reinterpret_cast<const BYTE*>(&value), sizeof(value),
                         0, &res, detail)) {
    return false;
  }
  if (!res.ok()) {
    std::ostringstream os;
    os << "SDIO_ControlDevice(0x" << std::hex << control_code << ") response=0x"
       << res.responseCode << " (" << PtpResponseName(res.responseCode) << ")";
    *detail = os.str();
    return false;
  }
  return true;
}

bool SonyCamera::GetObjectInfoFor(DWORD handle, ObjectInfo* out,
                                  std::string* detail) {
  DWORD params[1] = {handle};
  EscapeResult res;
  if (!transport_.Escape(kOcGetObjectInfo, params, 1, kNextPhaseReadData,
                         nullptr, 0, 0x1000, &res, detail)) {
    return false;
  }
  if (!res.ok()) {
    std::ostringstream os;
    os << "GetObjectInfo response=0x" << std::hex << res.responseCode << " ("
       << PtpResponseName(res.responseCode) << ")";
    *detail = os.str();
    return false;
  }

  // ObjectInfo dataset (PIMA 15740 / PTP standar), dibaca per offset.
  Reader r(res.data.data(), res.data.size());
  uint16_t protection = 0, thumb_format = 0;
  uint32_t thumb_size = 0, thumb_w = 0, thumb_h = 0, bit_depth = 0, parent = 0;
  if (!r.Read(&out->storage_id) || !r.Read(&out->object_format) ||
      !r.Read(&protection) || !r.Read(&out->compressed_size) ||
      !r.Read(&thumb_format) || !r.Read(&thumb_size) || !r.Read(&thumb_w) ||
      !r.Read(&thumb_h) || !r.Read(&out->pixel_width) ||
      !r.Read(&out->pixel_height) || !r.Read(&bit_depth) || !r.Read(&parent)) {
    *detail = "ObjectInfo dataset tidak lengkap";
    return false;
  }
  uint16_t assoc_type = 0;
  uint32_t assoc_desc = 0, sequence = 0;
  uint8_t name_chars = 0;
  if (r.Read(&assoc_type) && r.Read(&assoc_desc) && r.Read(&sequence) &&
      r.Read(&name_chars) && name_chars > 0) {
    const size_t at = r.offset();
    const size_t bytes = static_cast<size_t>(name_chars) * sizeof(wchar_t);
    if (at + bytes <= res.data.size()) {
      std::vector<wchar_t> chars(name_chars);
      memcpy(chars.data(), res.data.data() + at, bytes);
      int len = 0;
      while (len < name_chars && chars[len] != L'\0') ++len;
      out->filename = Utf16ToUtf8(chars.data(), len);
    }
  }
  return true;
}

bool SonyCamera::GetObjectData(DWORD handle, uint32_t size,
                               std::vector<BYTE>* out, std::string* detail) {
  DWORD params[1] = {handle};
  EscapeResult res;
  if (!transport_.Escape(kOcGetObject, params, 1, kNextPhaseReadData, nullptr,
                         0, size, &res, detail)) {
    return false;
  }
  if (!res.ok()) {
    std::ostringstream os;
    os << "GetObject response=0x" << std::hex << res.responseCode << " ("
       << PtpResponseName(res.responseCode) << ")";
    *detail = os.str();
    return false;
  }
  if (res.data.size() < size) {
    std::ostringstream os;
    os << "GetObject mengembalikan " << res.data.size() << " byte, diharapkan "
       << size;
    *detail = os.str();
    return false;
  }
  res.data.resize(size);
  out->swap(res.data);
  return true;
}

PrefocusResult SonyCamera::Prefocus(const CaptureOptions& opt) {
  PrefocusResult result;
  if (!connected_) {
    result.error_code = "not_connected";
    result.detail = "kamera belum terhubung";
    return result;
  }
  if (opt.af_mode == AfMode::kSkip) {
    result.error_code = "af_disabled";
    result.detail = "af_mode = skip, tidak ada fokus untuk dikunci";
    return result;
  }

  std::string detail;
  if (!s1_held_) {
    if (!ControlDevice(kDpcS1Button, kButtonDown, &detail)) {
      result.error_code = "s1_failed";
      result.detail = detail;
      return result;
    }
    s1_held_ = true;
  }

  const auto started = Clock::now();
  uint64_t last_af = 0;
  while (ElapsedMs(started) < opt.af_timeout_ms) {
    if (!RefreshProperties(&detail)) {
      ReleaseFocus();
      result.error_code = "status_read_failed";
      result.detail = detail;
      result.af_wait_ms = ElapsedMs(started);
      return result;
    }
    last_af = PropertyValue(kDpcFocusIndication, 0);
    if (AfStatusIsFocused(last_af)) {
      result.af_status = last_af;
      result.af_wait_ms = ElapsedMs(started);
      return result;
    }
    std::this_thread::sleep_for(
        std::chrono::milliseconds(opt.poll_interval_ms));
  }

  // AF belum mengunci. S1 SENGAJA tetap ditahan: kamera masih mencoba, dan
  // capture berikutnya akan menunggu sisa waktunya sendiri.
  result.af_status = last_af;
  result.af_wait_ms = ElapsedMs(started);
  result.error_code = AfStatusIsFailed(last_af) ? "af_failed" : "af_timeout";
  result.detail = std::string("status AF terakhir: ") + AfStatusLabel(last_af);
  return result;
}

void SonyCamera::ReleaseFocus() {
  if (!connected_ || !s1_held_) {
    s1_held_ = false;
    return;
  }
  std::string ignored;
  ControlDevice(kDpcS1Button, kButtonUp, &ignored);
  s1_held_ = false;
}

int SonyCamera::DrainShotBuffer(int max_files, std::string* detail) {
  int drained = 0;
  for (int i = 0; i < max_files; ++i) {
    if (!RefreshProperties(detail)) break;
    const uint64_t info = PropertyValue(kDpcShootingFileInfo, 0);
    if ((info & 0x7FFF) == 0) break;

    ObjectInfo object;
    if (!GetObjectInfoFor(kShotObjectHandle, &object, detail)) break;
    if (object.compressed_size == 0 ||
        object.compressed_size > 256u * 1024u * 1024u) {
      break;
    }
    std::vector<BYTE> discard;
    if (!GetObjectData(kShotObjectHandle, object.compressed_size, &discard,
                       detail)) {
      break;
    }
    ++drained;
  }
  return drained;
}

CaptureResult SonyCamera::Capture(const std::string& out_path,
                                  const CaptureOptions& opt) {
  CaptureResult result;
  result.path = out_path;
  const auto started = Clock::now();

  if (!connected_) {
    result.error_code = "not_connected";
    result.detail = "kamera belum terhubung";
    return result;
  }

  std::string detail;
  const auto sleep_tick = [&]() {
    std::this_thread::sleep_for(
        std::chrono::milliseconds(opt.poll_interval_ms));
  };

  // --- Fase 0: buang sisa berkas dari sesi sebelumnya ----------------------
  // Kalau buffer kamera masih berisi, berkas itulah yang akan terambil di fase
  // 4 dan pelanggan menerima foto jepretan sebelumnya. Harus dikosongkan dulu.
  if (!RefreshProperties(&detail)) {
    result.error_code = "status_read_failed";
    result.detail = detail;
    return result;
  }
  if ((PropertyValue(kDpcShootingFileInfo, 0) & 0x7FFF) != 0) {
    result.stale_discarded = DrainShotBuffer(8, &detail);
  }

  // --- Fase 1: setengah tekan (S1) dan tunggu status AF ---------------------
  //
  // Kalau Prefocus() sudah dipanggil selama hitungan mundur, S1 masih ditahan
  // dan AF kemungkinan sudah terkunci. Dalam hal itu fase ini langsung selesai
  // dan rana berbunyi hampir seketika. AF tetap DIPERIKSA, bukan diasumsikan.
  bool s1_pressed = s1_held_;
  if (opt.af_mode != AfMode::kSkip) {
    if (!s1_held_) {
      if (!ControlDevice(kDpcS1Button, kButtonDown, &detail)) {
        result.error_code = "s1_failed";
        result.detail = detail;
        return result;
      }
      s1_held_ = true;
      s1_pressed = true;
    } else {
      // Status terakhir sudah dibaca di fase 0 barusan.
      const uint64_t af_now = PropertyValue(kDpcFocusIndication, 0);
      if (AfStatusIsFocused(af_now)) {
        result.used_prefocus = true;
      }
    }

    const auto af_started = Clock::now();
    bool focused = result.used_prefocus;
    uint64_t last_af = result.used_prefocus
        ? PropertyValue(kDpcFocusIndication, 0)
        : 0;
    while (!focused && ElapsedMs(af_started) < opt.af_timeout_ms) {
      if (!RefreshProperties(&detail)) {
        ReleaseFocus();
        result.error_code = "status_read_failed";
        result.detail = detail;
        result.af_wait_ms = ElapsedMs(af_started);
        return result;
      }
      last_af = PropertyValue(kDpcFocusIndication, 0);
      if (AfStatusIsFocused(last_af)) {
        focused = true;
        break;
      }
      sleep_tick();
    }
    result.af_status = last_af;
    result.af_wait_ms = ElapsedMs(af_started);

    if (!focused) {
      result.af_timed_out = true;
      if (opt.af_mode == AfMode::kRequire) {
        ReleaseFocus();
        result.error_code =
            AfStatusIsFailed(last_af) ? "af_failed" : "af_timeout";
        result.detail = std::string("status AF terakhir: ") +
                        AfStatusLabel(last_af);
        result.elapsed_ms = ElapsedMs(started);
        return result;
      }
      // AfMode::kPrefer -> lanjut menjepret, tetapi dilaporkan apa adanya.
    }
  }

  // --- Fase 2: tekan penuh (S2) --------------------------------------------
  if (!ControlDevice(kDpcS2Button, kButtonDown, &detail)) {
    if (s1_pressed) ReleaseFocus();
    result.error_code = "s2_failed";
    result.detail = detail;
    result.elapsed_ms = ElapsedMs(started);
    return result;
  }
  // Durasi tahan tombol rana. Ini meniru penekanan tombol fisik, BUKAN
  // pengganti pembacaan status AF maupun status berkas.
  if (opt.s2_hold_ms > 0) {
    std::this_thread::sleep_for(std::chrono::milliseconds(opt.s2_hold_ms));
  }
  ControlDevice(kDpcS2Button, kButtonUp, &detail);
  if (s1_pressed) ReleaseFocus();

  // --- Fase 3: tunggu berkas siap (Shooting File Info, MSB = 1) ------------
  const auto file_started = Clock::now();
  bool file_ready = false;
  while (ElapsedMs(file_started) < opt.capture_timeout_ms) {
    if (!RefreshProperties(&detail)) {
      result.error_code = "status_read_failed";
      result.detail = detail;
      result.file_wait_ms = ElapsedMs(file_started);
      result.elapsed_ms = ElapsedMs(started);
      return result;
    }
    const uint64_t info = PropertyValue(kDpcShootingFileInfo, 0);
    if ((info & 0x8000) == 0x8000) {
      file_ready = true;
      break;
    }
    sleep_tick();
  }
  result.file_wait_ms = ElapsedMs(file_started);
  if (!file_ready) {
    result.error_code = "capture_timeout";
    result.detail = "kamera tidak melaporkan berkas hasil jepretan";
    result.elapsed_ms = ElapsedMs(started);
    return result;
  }

  // --- Fase 4: ambil berkas ------------------------------------------------
  ObjectInfo info;
  if (!GetObjectInfoFor(kShotObjectHandle, &info, &detail)) {
    result.error_code = "transfer_failed";
    result.detail = detail;
    result.elapsed_ms = ElapsedMs(started);
    return result;
  }
  result.object_format = info.object_format;
  if (info.compressed_size == 0 || info.compressed_size > 256u * 1024u * 1024u) {
    result.error_code = "transfer_failed";
    std::ostringstream os;
    os << "ukuran objek tidak masuk akal: " << info.compressed_size;
    result.detail = os.str();
    result.elapsed_ms = ElapsedMs(started);
    return result;
  }
  if (info.object_format != kObjectFormatExifJpeg) {
    // Jangan menyimpan berkas yang bukan JPEG lalu menyebutnya foto.
    DrainShotBuffer(8, &detail);
    result.error_code = "unexpected_format";
    std::ostringstream os;
    os << "format objek 0x" << std::hex << info.object_format
       << " bukan Exif/JPEG (0x3801) - periksa setelan File Format kamera";
    result.detail = os.str();
    result.elapsed_ms = ElapsedMs(started);
    return result;
  }

  std::vector<BYTE> bytes;
  if (!GetObjectData(kShotObjectHandle, info.compressed_size, &bytes, &detail)) {
    result.error_code = "transfer_failed";
    result.detail = detail;
    result.elapsed_ms = ElapsedMs(started);
    return result;
  }

  // Validasi JPEG: SOI di awal, EOI di akhir. Jangan pernah melaporkan sukses
  // untuk berkas yang rusak.
  if (bytes.size() < 4 || bytes[0] != 0xFF || bytes[1] != 0xD8 ||
      bytes[bytes.size() - 2] != 0xFF || bytes[bytes.size() - 1] != 0xD9) {
    result.error_code = "transfer_corrupt";
    result.detail = "penanda JPEG (SOI/EOI) tidak ditemukan";
    result.elapsed_ms = ElapsedMs(started);
    return result;
  }

  // --- Fase 5: tulis berkas secara atomik ----------------------------------
  const std::string temp_path = out_path + ".part";
  FILE* fp = nullptr;
  if (fopen_s(&fp, temp_path.c_str(), "wb") != 0 || fp == nullptr) {
    result.error_code = "write_failed";
    result.detail = "tidak bisa membuat " + temp_path;
    result.elapsed_ms = ElapsedMs(started);
    return result;
  }
  const size_t written = fwrite(bytes.data(), 1, bytes.size(), fp);
  fclose(fp);
  if (written != bytes.size()) {
    DeleteFileA(temp_path.c_str());
    result.error_code = "write_failed";
    result.detail = "penulisan berkas tidak lengkap";
    result.elapsed_ms = ElapsedMs(started);
    return result;
  }
  if (!MoveFileExA(temp_path.c_str(), out_path.c_str(),
                   MOVEFILE_REPLACE_EXISTING)) {
    DeleteFileA(temp_path.c_str());
    result.error_code = "write_failed";
    result.detail = "gagal memindahkan berkas sementara ke tujuan";
    result.elapsed_ms = ElapsedMs(started);
    return result;
  }

  result.bytes = bytes.size();
  result.camera_filename = info.filename;

  // Dimensi diambil dari berkas yang benar-benar tertulis. Kamera melaporkan
  // 0x0 untuk objek buffer, jadi nilai dari ObjectInfo hanya dipakai kalau
  // pembacaan penanda SOF gagal.
  uint32_t jpeg_w = 0, jpeg_h = 0;
  if (ParseJpegDimensions(bytes, &jpeg_w, &jpeg_h)) {
    result.width = jpeg_w;
    result.height = jpeg_h;
  } else {
    result.width = info.pixel_width;
    result.height = info.pixel_height;
  }

  // Sisa berkas (misalnya ARW pada mode RAW+JPEG) harus dikosongkan, kalau
  // tidak akan terambil sebagai "foto" pada capture berikutnya.
  result.extra_discarded = DrainShotBuffer(8, &detail);

  result.elapsed_ms = ElapsedMs(started);
  return result;
}

}  // namespace stb
