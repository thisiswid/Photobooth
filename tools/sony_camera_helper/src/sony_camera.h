// SnapTechBooth - Sony camera helper
// Lapisan protokol "Camera Control PTP" di atas transport WIA.
#pragma once

#include <cstdint>
#include <map>
#include <string>
#include <vector>

#include "ptp_wia.h"

namespace stb {

// ---- Operation codes (Camera Control PTP 3 Reference) ----------------------
constexpr WORD kOcGetObjectInfo = 0x1008;
constexpr WORD kOcGetObject = 0x1009;
constexpr WORD kOcCloseSession = 0x1003;
constexpr WORD kOcSdioConnect = 0x9201;
constexpr WORD kOcSdioGetExtDeviceInfo = 0x9202;
constexpr WORD kOcSdioSetExtDevicePropValue = 0x9205;
constexpr WORD kOcSdioControlDevice = 0x9207;
constexpr WORD kOcSdioGetAllExtDevicePropInfo = 0x9209;

// ---- Device property codes -------------------------------------------------
constexpr uint16_t kDpcFocusIndication = 0xD213;       // "AF status"
constexpr uint16_t kDpcShootingFileInfo = 0xD215;
constexpr uint16_t kDpcPositionKey = 0xD25A;
constexpr uint16_t kDpcS1Button = 0xD2C1;
constexpr uint16_t kDpcS2Button = 0xD2C2;

// ---- Nilai kontrol ---------------------------------------------------------
constexpr uint32_t kButtonUp = 0x0001;
constexpr uint32_t kButtonDown = 0x0002;

constexpr DWORD kSdiExtensionVersion = 0x12C;
constexpr DWORD kSdioConnectId = 0x00000000;
constexpr DWORD kShotObjectHandle = 0xFFFFC001;

// Nilai Focus Indication (0xD213), Reference hal. 442.
constexpr uint64_t kAfUnlock = 0x01;
constexpr uint64_t kAfSFocused = 0x02;
constexpr uint64_t kAfSNotFocused = 0x03;
constexpr uint64_t kAfCTracking = 0x05;
constexpr uint64_t kAfCFocused = 0x06;
constexpr uint64_t kAfCNotFocused = 0x07;

const char* AfStatusLabel(uint64_t value);
bool AfStatusIsFocused(uint64_t value);
bool AfStatusIsFailed(uint64_t value);

struct DeviceProperty {
  uint16_t code = 0;
  uint16_t data_type = 0;
  uint8_t get_set = 0;
  uint8_t is_enabled = 0;
  uint64_t current_value = 0;
};

// Format objek PTP yang relevan.
constexpr uint16_t kObjectFormatExifJpeg = 0x3801;

struct ObjectInfo {
  uint32_t storage_id = 0;
  uint16_t object_format = 0;
  uint32_t compressed_size = 0;
  uint32_t pixel_width = 0;
  uint32_t pixel_height = 0;
  std::string filename;
};

enum class AfMode {
  kRequire,  // wajib fokus; gagal fokus = gagal capture
  kPrefer,   // tunggu fokus, tetap jepret bila timeout (dilaporkan apa adanya)
  kSkip,     // tanpa S1 sama sekali (manual focus)
};

struct CaptureOptions {
  AfMode af_mode = AfMode::kRequire;
  int af_timeout_ms = 5000;
  int capture_timeout_ms = 20000;
  int poll_interval_ms = 40;
  int s2_hold_ms = 200;  // durasi tekan tombol, BUKAN pengganti status AF
};

/// Hasil pra-fokus (S1 ditahan, menunggu AF mengunci).
struct PrefocusResult {
  std::string error_code;  // kosong = fokus terkunci
  std::string detail;
  uint64_t af_status = 0;
  int af_wait_ms = 0;
  bool ok() const { return error_code.empty(); }
};

struct CaptureResult {
  std::string error_code;  // kosong = sukses
  std::string detail;
  std::string path;
  uint64_t bytes = 0;
  uint32_t width = 0;
  uint32_t height = 0;
  std::string camera_filename;
  uint16_t object_format = 0;
  int stale_discarded = 0;   // berkas basi yang dibuang SEBELUM menjepret
  int extra_discarded = 0;   // berkas sisa yang dibuang SESUDAH menjepret
  uint64_t af_status = 0;
  bool af_timed_out = false;
  bool used_prefocus = false;  // fokus sudah terkunci sebelum perintah ini
  int af_wait_ms = 0;
  int file_wait_ms = 0;
  int elapsed_ms = 0;
  bool ok() const { return error_code.empty(); }
};

class SonyCamera {
 public:
  bool Connect(const std::wstring& device_id, const std::wstring& name_filter,
               std::string* error_code, std::string* detail);
  void Disconnect();
  bool connected() const { return connected_; }

  const std::wstring& device_id() const { return transport_.device_id(); }
  const std::wstring& device_name() const { return transport_.device_name(); }

  // Ambil ulang seluruh dataset properti (SDIO_GetAllExtDevicePropInfo).
  // Ini mekanisme resmi: Reference menginstruksikan Initiator melakukan
  // pembacaan status berkala dan TIDAK memakai PTP vendor event.
  bool RefreshProperties(std::string* detail);
  bool GetProperty(uint16_t code, DeviceProperty* out) const;
  uint64_t PropertyValue(uint16_t code, uint64_t fallback = 0) const;

  CaptureResult Capture(const std::string& out_path, const CaptureOptions& opt);

  /// Tekan S1 dan tunggu AF mengunci, LALU TAHAN.
  ///
  /// Dipanggil saat hitungan mundur masih berjalan, supaya saat tombol jepret
  /// tiba yang tersisa hanya S2 — rana berbunyi hampir seketika, bukan setelah
  /// menunggu AF. Sama seperti fotografer menahan setengah tekan sebelum
  /// momennya. AF tetap ditunggu sungguhan, tidak dilewati.
  PrefocusResult Prefocus(const CaptureOptions& opt);

  /// Lepas S1 tanpa menjepret (mis. sesi dibatalkan).
  void ReleaseFocus();

  bool focusHeld() const { return s1_held_; }

 private:
  bool ControlDevice(uint16_t control_code, uint32_t value, std::string* detail);
  bool GetObjectInfoFor(DWORD handle, ObjectInfo* out, std::string* detail);
  bool GetObjectData(DWORD handle, uint32_t size, std::vector<BYTE>* out,
                     std::string* detail);
  bool ParsePropertyDataset(const std::vector<BYTE>& data, std::string* detail);
  // Kosongkan buffer transfer kamera sampai Shooting File Info bernilai nol.
  // Reference: Initiator harus mengambil handle yang sama berulang kali sampai
  // properti itu nol, kalau tidak sisa berkas akan terbawa ke capture berikutnya.
  int DrainShotBuffer(int max_files, std::string* detail);

  PtpWiaTransport transport_;
  bool connected_ = false;
  bool s1_held_ = false;
  std::map<uint16_t, DeviceProperty> props_;
};

}  // namespace stb
