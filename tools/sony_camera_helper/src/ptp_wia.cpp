#include "ptp_wia.h"

#include <objbase.h>
#include <sti.h>

#include <cstring>

#include <sstream>

namespace stb {
namespace {

std::string HrToText(const char* what, HRESULT hr) {
  std::ostringstream os;
  os << what << " gagal (hr=0x" << std::hex << static_cast<unsigned>(hr) << ")";
  return os.str();
}

// Baca satu properti string dari IWiaPropertyStorage.
bool ReadStringProp(IWiaPropertyStorage* store, PROPID id, std::wstring* out) {
  PROPSPEC spec = {};
  spec.ulKind = PRSPEC_PROPID;
  spec.propid = id;
  PROPVARIANT var;
  PropVariantInit(&var);
  HRESULT hr = store->ReadMultiple(1, &spec, &var);
  bool ok = false;
  if (SUCCEEDED(hr)) {
    if (var.vt == VT_BSTR && var.bstrVal != nullptr) {
      out->assign(var.bstrVal, SysStringLen(var.bstrVal));
      ok = true;
    } else if (var.vt == VT_LPWSTR && var.pwszVal != nullptr) {
      out->assign(var.pwszVal);
      ok = true;
    }
  }
  PropVariantClear(&var);
  return ok;
}

bool ReadLongProp(IWiaPropertyStorage* store, PROPID id, LONG* out) {
  PROPSPEC spec = {};
  spec.ulKind = PRSPEC_PROPID;
  spec.propid = id;
  PROPVARIANT var;
  PropVariantInit(&var);
  HRESULT hr = store->ReadMultiple(1, &spec, &var);
  bool ok = false;
  if (SUCCEEDED(hr) && (var.vt == VT_I4 || var.vt == VT_UI4)) {
    *out = var.lVal;
    ok = true;
  }
  PropVariantClear(&var);
  return ok;
}

bool ContainsNoCase(const std::wstring& hay, const std::wstring& needle) {
  if (needle.empty()) return true;
  if (needle.size() > hay.size()) return false;
  auto lower = [](wchar_t c) -> wchar_t {
    return (c >= L'A' && c <= L'Z') ? static_cast<wchar_t>(c - L'A' + L'a') : c;
  };
  for (size_t i = 0; i + needle.size() <= hay.size(); ++i) {
    size_t j = 0;
    for (; j < needle.size(); ++j) {
      if (lower(hay[i + j]) != lower(needle[j])) break;
    }
    if (j == needle.size()) return true;
  }
  return false;
}

}  // namespace

PtpWiaTransport::~PtpWiaTransport() { Close(); }

bool PtpWiaTransport::ListCameras(std::vector<WiaCamera>* out,
                                  std::string* err) {
  out->clear();
  IWiaDevMgr* dev_mgr = nullptr;
  HRESULT hr = CoCreateInstance(CLSID_WiaDevMgr, nullptr, CLSCTX_LOCAL_SERVER,
                                IID_IWiaDevMgr, reinterpret_cast<void**>(&dev_mgr));
  if (FAILED(hr) || dev_mgr == nullptr) {
    *err = HrToText("CoCreateInstance(CLSID_WiaDevMgr)", hr);
    return false;
  }

  IEnumWIA_DEV_INFO* enum_info = nullptr;
  hr = dev_mgr->EnumDeviceInfo(WIA_DEVINFO_ENUM_LOCAL, &enum_info);
  if (FAILED(hr) || enum_info == nullptr) {
    dev_mgr->Release();
    *err = HrToText("IWiaDevMgr::EnumDeviceInfo", hr);
    return false;
  }

  for (;;) {
    IWiaPropertyStorage* store = nullptr;
    ULONG fetched = 0;
    hr = enum_info->Next(1, &store, &fetched);
    if (hr != S_OK || fetched != 1 || store == nullptr) break;

    LONG dev_type = 0;
    std::wstring id;
    std::wstring name;
    const bool has_type = ReadLongProp(store, WIA_DIP_DEV_TYPE, &dev_type);
    ReadStringProp(store, WIA_DIP_DEV_ID, &id);
    if (!ReadStringProp(store, WIA_DIP_DEV_NAME, &name)) {
      ReadStringProp(store, WIA_DIP_DEV_DESC, &name);
    }
    store->Release();

    if (id.empty()) continue;
    if (has_type && GET_STIDEVICE_TYPE(dev_type) != StiDeviceTypeDigitalCamera) {
      continue;
    }
    out->push_back(WiaCamera{id, name});
  }

  enum_info->Release();
  dev_mgr->Release();
  return true;
}

bool PtpWiaTransport::Open(const std::wstring& device_id,
                           const std::wstring& name_filter, std::string* err) {
  Close();

  std::vector<WiaCamera> cameras;
  if (!ListCameras(&cameras, err)) return false;

  const WiaCamera* chosen = nullptr;
  for (const auto& cam : cameras) {
    if (!device_id.empty()) {
      if (cam.id == device_id) {
        chosen = &cam;
        break;
      }
      continue;
    }
    if (ContainsNoCase(cam.name, name_filter)) {
      chosen = &cam;
      break;
    }
  }
  if (chosen == nullptr) {
    *err = cameras.empty()
               ? "tidak ada kamera WIA terdeteksi (pastikan kamera menyala, "
                 "USB Connection = PC Remote, dan driver WPD/MTP aktif)"
               : "kamera yang cocok tidak ditemukan";
    return false;
  }

  IWiaDevMgr* dev_mgr = nullptr;
  HRESULT hr = CoCreateInstance(CLSID_WiaDevMgr, nullptr, CLSCTX_LOCAL_SERVER,
                                IID_IWiaDevMgr, reinterpret_cast<void**>(&dev_mgr));
  if (FAILED(hr) || dev_mgr == nullptr) {
    *err = HrToText("CoCreateInstance(CLSID_WiaDevMgr)", hr);
    return false;
  }

  BSTR bstr_id = SysAllocString(chosen->id.c_str());
  IWiaItem* root = nullptr;
  hr = dev_mgr->CreateDevice(bstr_id, &root);
  SysFreeString(bstr_id);
  dev_mgr->Release();
  if (FAILED(hr) || root == nullptr) {
    *err = HrToText("IWiaDevMgr::CreateDevice", hr);
    return false;
  }

  IWiaItemExtras* extras = nullptr;
  hr = root->QueryInterface(IID_IWiaItemExtras,
                            reinterpret_cast<void**>(&extras));
  root->Release();
  if (FAILED(hr) || extras == nullptr) {
    *err = HrToText("QueryInterface(IID_IWiaItemExtras)", hr);
    return false;
  }

  item_extras_ = extras;
  device_id_ = chosen->id;
  device_name_ = chosen->name;
  return true;
}

void PtpWiaTransport::Close() {
  if (item_extras_ != nullptr) {
    item_extras_->Release();
    item_extras_ = nullptr;
  }
  device_id_.clear();
  device_name_.clear();
}

bool PtpWiaTransport::Escape(WORD op_code, const DWORD* params,
                             DWORD num_params, DWORD next_phase,
                             const BYTE* write_data, DWORD write_size,
                             DWORD read_capacity, EscapeResult* out,
                             std::string* err) {
  if (item_extras_ == nullptr) {
    *err = "transport WIA belum terbuka";
    return false;
  }
  if (num_params > kPtpMaxParams) {
    *err = "num_params melebihi batas PTP";
    return false;
  }

  const DWORD in_size = kVendorDataInHeader + write_size;
  const DWORD out_size = kVendorDataOutHeader + read_capacity;

  auto* data_in = static_cast<PtpVendorDataIn*>(CoTaskMemAlloc(in_size));
  if (data_in == nullptr) {
    *err = "alokasi buffer perintah gagal";
    return false;
  }
  // Alokasikan satu byte lebih supaya &VendorReadData[0] tetap valid walau
  // read_capacity == 0. Ukuran yang dilaporkan ke driver tetap out_size.
  auto* data_out =
      static_cast<PtpVendorDataOut*>(CoTaskMemAlloc(out_size + 1));
  if (data_out == nullptr) {
    CoTaskMemFree(data_in);
    *err = "alokasi buffer balasan gagal";
    return false;
  }
  ZeroMemory(data_in, in_size);
  ZeroMemory(data_out, out_size + 1);

  data_in->OpCode = op_code;
  data_in->NextPhase = next_phase;
  data_in->NumParams = num_params;
  for (DWORD i = 0; i < num_params; ++i) data_in->Params[i] = params[i];
  if (write_size > 0 && write_data != nullptr) {
    memcpy(data_in->VendorWriteData, write_data, write_size);
  }

  DWORD actual = 0;
  HRESULT hr = item_extras_->Escape(
      kEscapePtpVendorCommand, reinterpret_cast<BYTE*>(data_in), in_size,
      reinterpret_cast<BYTE*>(data_out), out_size, &actual);

  bool ok = false;
  if (SUCCEEDED(hr)) {
    out->responseCode = data_out->ResponseCode;
    for (DWORD i = 0; i < kPtpMaxParams; ++i) out->params[i] = data_out->Params[i];

    DWORD payload = 0;
    if (actual >= kVendorDataOutHeader) {
      payload = actual - kVendorDataOutHeader;
    } else {
      payload = actual;  // driver melaporkan payload saja
    }
    if (payload > read_capacity) payload = read_capacity;
    out->data.assign(data_out->VendorReadData,
                     data_out->VendorReadData + payload);
    ok = true;
  } else {
    std::ostringstream os;
    os << "IWiaItemExtras::Escape(op=0x" << std::hex << op_code
       << ") gagal (hr=0x" << static_cast<unsigned>(hr) << ")";
    *err = os.str();
  }

  CoTaskMemFree(data_in);
  CoTaskMemFree(data_out);
  return ok;
}

}  // namespace stb
