// SnapTechBooth - Sony camera helper
// WIA transport for Sony "Camera Control PTP" vendor commands.
//
// Ditulis sendiri berdasarkan:
//   - Sony "Camera Control PTP 3 Reference" (spesifikasi protokol)
//   - MS-WIA: IWiaItemExtras::Escape (transport)
// Contoh program Sony HANYA dipakai sebagai rujukan pemahaman; tidak ada
// kode contoh Sony yang disalin ke dalam produk (lihat Instruction Manual:
// "please do not use them in your products").
#pragma once

#include <windows.h>
#include <wia.h>

#include <cstdint>
#include <string>
#include <vector>

namespace stb {

// ---- Konstanta transport (MS-WIA / PTP vendor escape) ----------------------
constexpr DWORD kEscapePtpVendorCommand = 0x0100;
constexpr DWORD kPtpMaxParams = 5;
constexpr DWORD kNextPhaseReadData = 3;
constexpr DWORD kNextPhaseWriteData = 4;
constexpr DWORD kNextPhaseNoData = 5;
constexpr WORD kPtpRcOk = 0x2001;

#pragma pack(push, ptpvd, 1)
struct PtpVendorDataIn {
  WORD OpCode;
  DWORD SessionId;
  DWORD TransactionId;
  DWORD Params[kPtpMaxParams];
  DWORD NumParams;
  DWORD NextPhase;
  BYTE VendorWriteData[1];
};
struct PtpVendorDataOut {
  WORD ResponseCode;
  DWORD SessionId;
  DWORD TransactionId;
  DWORD Params[kPtpMaxParams];
  BYTE VendorReadData[1];
};
#pragma pack(pop, ptpvd)

constexpr DWORD kVendorDataInHeader = sizeof(PtpVendorDataIn) - 1;
constexpr DWORD kVendorDataOutHeader = sizeof(PtpVendorDataOut) - 1;

struct WiaCamera {
  std::wstring id;
  std::wstring name;
};

// Hasil satu perintah vendor.
struct EscapeResult {
  WORD responseCode = 0;
  DWORD params[kPtpMaxParams] = {0, 0, 0, 0, 0};
  std::vector<BYTE> data;  // payload (VendorReadData), sudah dipotong
  bool ok() const { return responseCode == kPtpRcOk; }
};

// Transport WIA headless. Tidak ada dialog, tidak ada UI, tidak ada MFC.
class PtpWiaTransport {
 public:
  PtpWiaTransport() = default;
  ~PtpWiaTransport();
  PtpWiaTransport(const PtpWiaTransport&) = delete;
  PtpWiaTransport& operator=(const PtpWiaTransport&) = delete;

  // Enumerasi semua device WIA bertipe kamera digital (tanpa SelectDeviceDlg).
  static bool ListCameras(std::vector<WiaCamera>* out, std::string* err);

  // Buka device. deviceId kosong -> pakai kamera pertama yang cocok dengan
  // nameFilter (juga boleh kosong -> kamera pertama yang ada).
  bool Open(const std::wstring& deviceId, const std::wstring& nameFilter,
            std::string* err);
  void Close();
  bool IsOpen() const { return item_extras_ != nullptr; }

  const std::wstring& device_id() const { return device_id_; }
  const std::wstring& device_name() const { return device_name_; }

  // Perintah vendor generik.
  //   read_capacity: byte yang disediakan untuk payload balasan.
  bool Escape(WORD op_code, const DWORD* params, DWORD num_params,
              DWORD next_phase, const BYTE* write_data, DWORD write_size,
              DWORD read_capacity, EscapeResult* out, std::string* err);

 private:
  IWiaItemExtras* item_extras_ = nullptr;
  std::wstring device_id_;
  std::wstring device_name_;
};

}  // namespace stb
