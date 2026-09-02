// SnapTechBooth - sony_camera_helper
//
// Proses terpisah yang mengendalikan Sony ZV-E10 lewat "Camera Control PTP"
// (transport WIA) dan mengeksposnya sebagai socket localhost berbasis baris
// JSON. Dipisah dari aplikasi kiosk supaya lapisan kamera yang macet tidak
// pernah mematikan sesi pelanggan.
#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#include <winsock2.h>
#include <ws2tcpip.h>
#include <windows.h>
#include <objbase.h>

#include <cstdio>
#include <cstdlib>
#include <ctime>
#include <map>
#include <string>
#include <vector>

#include "json_min.h"
#include "sony_camera.h"

#pragma comment(lib, "ws2_32.lib")
#pragma comment(lib, "ole32.lib")
#pragma comment(lib, "oleaut32.lib")
#pragma comment(lib, "wiaguid.lib")

namespace {

using stb::AfMode;
using stb::AfStatusLabel;
using stb::CaptureOptions;
using stb::CaptureResult;
using stb::JsonWriter;
using stb::SonyCamera;

struct Config {
  int port = 45455;
  std::string out_dir;
  std::wstring device_id;
  std::wstring device_name;
  std::string token;
  CaptureOptions capture;
  int command_timeout_ms = 60000;
  bool verbose = false;
};

Config g_config;
SonyCamera g_camera;

std::string WideToUtf8(const std::wstring& in) {
  if (in.empty()) return std::string();
  int needed = WideCharToMultiByte(CP_UTF8, 0, in.c_str(),
                                   static_cast<int>(in.size()), nullptr, 0,
                                   nullptr, nullptr);
  if (needed <= 0) return std::string();
  std::string out(static_cast<size_t>(needed), '\0');
  WideCharToMultiByte(CP_UTF8, 0, in.c_str(), static_cast<int>(in.size()),
                      &out[0], needed, nullptr, nullptr);
  return out;
}

std::wstring Utf8ToWide(const std::string& in) {
  if (in.empty()) return std::wstring();
  int needed = MultiByteToWideChar(CP_UTF8, 0, in.c_str(),
                                   static_cast<int>(in.size()), nullptr, 0);
  if (needed <= 0) return std::wstring();
  std::wstring out(static_cast<size_t>(needed), L'\0');
  MultiByteToWideChar(CP_UTF8, 0, in.c_str(), static_cast<int>(in.size()),
                      &out[0], needed);
  return out;
}

void LogLine(const std::string& text) {
  if (!g_config.verbose) return;
  SYSTEMTIME st;
  GetLocalTime(&st);
  fprintf(stderr, "[%02d:%02d:%02d.%03d] %s\n", st.wHour, st.wMinute,
          st.wSecond, st.wMilliseconds, text.c_str());
  fflush(stderr);
}

std::string DefaultOutDir() {
  char buf[MAX_PATH] = {0};
  DWORD n = GetTempPathA(MAX_PATH, buf);
  if (n == 0 || n > MAX_PATH) return ".";
  std::string dir = std::string(buf) + "snaptechbooth_captures";
  CreateDirectoryA(dir.c_str(), nullptr);
  return dir;
}

std::string MakeOutputPath() {
  static unsigned counter = 0;
  SYSTEMTIME st;
  GetLocalTime(&st);
  char name[128];
  snprintf(name, sizeof(name), "stb_%04d%02d%02d_%02d%02d%02d_%03d_%u.jpg",
           st.wYear, st.wMonth, st.wDay, st.wHour, st.wMinute, st.wSecond,
           st.wMilliseconds, ++counter);
  std::string dir = g_config.out_dir.empty() ? DefaultOutDir() : g_config.out_dir;
  if (!dir.empty() && dir.back() != '\\' && dir.back() != '/') dir += '\\';
  return dir + name;
}

// ---------------------------------------------------------------------------
// Perintah kamera. Semua fungsi di bawah ini HANYA dipanggil dari worker STA.
// ---------------------------------------------------------------------------

void AddCameraStatus(JsonWriter* w) {
  const uint64_t af = g_camera.PropertyValue(stb::kDpcFocusIndication, 0);
  const uint64_t sf = g_camera.PropertyValue(stb::kDpcShootingFileInfo, 0);
  w->UInt("af_status", af)
      .Str("af_label", AfStatusLabel(af))
      .Bool("af_focused", stb::AfStatusIsFocused(af))
      .UInt("shooting_file_info", sf)
      .Bool("file_ready", (sf & 0x8000) == 0x8000)
      .UInt("pending_files", sf & 0x7FFF);
}

std::string CmdConnect() {
  JsonWriter w;
  w.Str("cmd", "connect");
  if (g_camera.connected()) {
    return w.Bool("ok", true)
        .Bool("already_connected", true)
        .Str("device", WideToUtf8(g_camera.device_name()))
        .Str("device_id", WideToUtf8(g_camera.device_id()))
        .Done();
  }
  std::string code, detail;
  if (!g_camera.Connect(g_config.device_id, g_config.device_name, &code,
                        &detail)) {
    return w.Bool("ok", false).Str("error", code).Str("detail", detail).Done();
  }
  w.Bool("ok", true)
      .Bool("already_connected", false)
      .Str("device", WideToUtf8(g_camera.device_name()))
      .Str("device_id", WideToUtf8(g_camera.device_id()));
  AddCameraStatus(&w);
  return w.Done();
}

std::string CmdDisconnect() {
  const bool was = g_camera.connected();
  g_camera.Disconnect();
  return JsonWriter()
      .Str("cmd", "disconnect")
      .Bool("ok", true)
      .Bool("was_connected", was)
      .Done();
}

std::string CmdStatus() {
  JsonWriter w;
  w.Str("cmd", "status").Bool("connected", g_camera.connected());
  if (!g_camera.connected()) {
    return w.Bool("ok", true).Done();
  }
  std::string detail;
  if (!g_camera.RefreshProperties(&detail)) {
    // Kamera tidak menjawab lagi: jangan berpura-pura masih siap.
    g_camera.Disconnect();
    return w.Bool("ok", false)
        .Str("error", "status_read_failed")
        .Str("detail", detail)
        .Bool("connected", false)
        .Done();
  }
  w.Bool("ok", true)
      .Str("device", WideToUtf8(g_camera.device_name()))
      .Str("device_id", WideToUtf8(g_camera.device_id()));
  AddCameraStatus(&w);
  return w.Done();
}

std::string CmdCapture(const std::map<std::string, std::string>& req) {
  JsonWriter w;
  w.Str("cmd", "capture");
  if (!g_camera.connected()) {
    return w.Bool("ok", false)
        .Str("error", "not_connected")
        .Str("detail", "panggil connect terlebih dahulu")
        .Done();
  }

  CaptureOptions opt = g_config.capture;
  auto it = req.find("af_mode");
  if (it != req.end()) {
    if (it->second == "require") opt.af_mode = AfMode::kRequire;
    else if (it->second == "prefer") opt.af_mode = AfMode::kPrefer;
    else if (it->second == "skip") opt.af_mode = AfMode::kSkip;
  }
  it = req.find("af_timeout_ms");
  if (it != req.end()) opt.af_timeout_ms = atoi(it->second.c_str());
  it = req.find("capture_timeout_ms");
  if (it != req.end()) opt.capture_timeout_ms = atoi(it->second.c_str());

  std::string path;
  it = req.find("path");
  if (it != req.end() && !it->second.empty()) {
    path = it->second;
  } else {
    path = MakeOutputPath();
  }

  const CaptureResult r = g_camera.Capture(path, opt);
  w.Bool("ok", r.ok())
      .Int("af_wait_ms", r.af_wait_ms)
      .Int("file_wait_ms", r.file_wait_ms)
      .Int("elapsed_ms", r.elapsed_ms)
      .UInt("af_status", r.af_status)
      .Str("af_label", AfStatusLabel(r.af_status))
      .Bool("af_timed_out", r.af_timed_out);
  if (r.ok()) {
    w.Str("path", r.path)
        .UInt("bytes", r.bytes)
        .UInt("width", r.width)
        .UInt("height", r.height)
        .Str("camera_filename", r.camera_filename);
  } else {
    w.Str("error", r.error_code).Str("detail", r.detail);
  }
  return w.Done();
}

std::string CmdList() {
  std::vector<stb::WiaCamera> cameras;
  std::string err;
  JsonWriter w;
  w.Str("cmd", "list");
  if (!stb::PtpWiaTransport::ListCameras(&cameras, &err)) {
    return w.Bool("ok", false).Str("error", "wia_error").Str("detail", err).Done();
  }
  std::string array = "[";
  for (size_t i = 0; i < cameras.size(); ++i) {
    if (i > 0) array += ",";
    array += JsonWriter()
                 .Str("id", WideToUtf8(cameras[i].id))
                 .Str("name", WideToUtf8(cameras[i].name))
                 .Done();
  }
  array += "]";
  return w.Bool("ok", true).Int("count", static_cast<long long>(cameras.size()))
      .Raw("cameras", array)
      .Done();
}

std::string HandleRequestLine(const std::string& line) {
  std::map<std::string, std::string> req;
  if (!stb::JsonParseFlat(line, &req)) {
    return JsonWriter()
        .Bool("ok", false)
        .Str("error", "bad_request")
        .Str("detail", "baris bukan objek JSON datar yang valid")
        .Done();
  }
  auto it = req.find("cmd");
  if (it == req.end()) {
    return JsonWriter()
        .Bool("ok", false)
        .Str("error", "bad_request")
        .Str("detail", "field \"cmd\" tidak ada")
        .Done();
  }
  const std::string& cmd = it->second;

  if (!g_config.token.empty()) {
    auto t = req.find("token");
    if (t == req.end() || t->second != g_config.token) {
      return JsonWriter()
          .Str("cmd", cmd)
          .Bool("ok", false)
          .Str("error", "unauthorized")
          .Done();
    }
  }

  if (cmd == "ping") {
    return JsonWriter().Str("cmd", "ping").Bool("ok", true)
        .Bool("connected", g_camera.connected()).Done();
  }
  if (cmd == "list") return CmdList();
  if (cmd == "connect") return CmdConnect();
  if (cmd == "disconnect") return CmdDisconnect();
  if (cmd == "status") return CmdStatus();
  if (cmd == "capture") return CmdCapture(req);
  if (cmd == "shutdown") {
    g_camera.Disconnect();
    return JsonWriter().Str("cmd", "shutdown").Bool("ok", true).Done();
  }
  return JsonWriter()
      .Str("cmd", cmd)
      .Bool("ok", false)
      .Str("error", "bad_request")
      .Str("detail", "perintah tidak dikenal")
      .Done();
}

// ---------------------------------------------------------------------------
// Worker STA. Semua panggilan WIA/COM terjadi di thread ini.
// ---------------------------------------------------------------------------

struct Worker {
  HANDLE request_ready = nullptr;
  HANDLE response_ready = nullptr;
  HANDLE quit = nullptr;
  HANDLE thread = nullptr;
  std::string request;
  std::string response;
  volatile LONG stuck = 0;
};

Worker g_worker;

DWORD WINAPI WorkerProc(LPVOID) {
  HRESULT hr = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
  if (FAILED(hr)) {
    fprintf(stderr, "CoInitializeEx gagal (0x%08lx)\n", static_cast<unsigned long>(hr));
    return 1;
  }
  HANDLE waits[2] = {g_worker.quit, g_worker.request_ready};
  for (;;) {
    DWORD rc = MsgWaitForMultipleObjects(2, waits, FALSE, INFINITE, QS_ALLINPUT);
    if (rc == WAIT_OBJECT_0) break;
    if (rc == WAIT_OBJECT_0 + 1) {
      g_worker.response = HandleRequestLine(g_worker.request);
      SetEvent(g_worker.response_ready);
      continue;
    }
    // Pesan window/COM: pompa antrean supaya marshaling STA tetap sehat.
    MSG msg;
    while (PeekMessage(&msg, nullptr, 0, 0, PM_REMOVE)) {
      TranslateMessage(&msg);
      DispatchMessage(&msg);
    }
  }
  g_camera.Disconnect();
  CoUninitialize();
  return 0;
}

// Kirim satu baris permintaan ke worker dan tunggu balasannya.
std::string Dispatch(const std::string& line) {
  if (InterlockedCompareExchange(&g_worker.stuck, 0, 0) != 0) {
    // Worker sebelumnya belum selesai. Cek apakah sudah pulih.
    if (WaitForSingleObject(g_worker.response_ready, 0) == WAIT_OBJECT_0) {
      InterlockedExchange(&g_worker.stuck, 0);
    } else {
      return JsonWriter()
          .Bool("ok", false)
          .Str("error", "busy")
          .Str("detail", "perintah kamera sebelumnya masih berjalan")
          .Done();
    }
  }

  g_worker.request = line;
  SetEvent(g_worker.request_ready);
  DWORD rc = WaitForSingleObject(g_worker.response_ready,
                                 static_cast<DWORD>(g_config.command_timeout_ms));
  if (rc != WAIT_OBJECT_0) {
    InterlockedExchange(&g_worker.stuck, 1);
    return JsonWriter()
        .Bool("ok", false)
        .Str("error", "timeout")
        .Str("detail", "lapisan kamera tidak merespons dalam batas waktu")
        .Done();
  }
  return g_worker.response;
}

bool StartWorker() {
  g_worker.request_ready = CreateEvent(nullptr, FALSE, FALSE, nullptr);
  g_worker.response_ready = CreateEvent(nullptr, FALSE, FALSE, nullptr);
  g_worker.quit = CreateEvent(nullptr, TRUE, FALSE, nullptr);
  if (!g_worker.request_ready || !g_worker.response_ready || !g_worker.quit) {
    return false;
  }
  g_worker.thread = CreateThread(nullptr, 0, WorkerProc, nullptr, 0, nullptr);
  return g_worker.thread != nullptr;
}

void StopWorker() {
  if (g_worker.quit) SetEvent(g_worker.quit);
  if (g_worker.thread) {
    WaitForSingleObject(g_worker.thread, 5000);
    CloseHandle(g_worker.thread);
    g_worker.thread = nullptr;
  }
}

// ---------------------------------------------------------------------------
// Server socket loopback.
// ---------------------------------------------------------------------------

bool SendAll(SOCKET s, const std::string& data) {
  size_t sent = 0;
  while (sent < data.size()) {
    int n = send(s, data.data() + sent, static_cast<int>(data.size() - sent), 0);
    if (n <= 0) return false;
    sent += static_cast<size_t>(n);
  }
  return true;
}

void ServeClient(SOCKET client, bool* shutdown_requested) {
  std::string buffer;
  char chunk[4096];
  for (;;) {
    int n = recv(client, chunk, sizeof(chunk), 0);
    if (n <= 0) return;
    buffer.append(chunk, static_cast<size_t>(n));
    if (buffer.size() > 1024 * 1024) {
      SendAll(client, JsonWriter()
                          .Bool("ok", false)
                          .Str("error", "bad_request")
                          .Str("detail", "baris terlalu panjang")
                          .Done() + "\n");
      return;
    }
    size_t pos;
    while ((pos = buffer.find('\n')) != std::string::npos) {
      std::string line = buffer.substr(0, pos);
      buffer.erase(0, pos + 1);
      if (!line.empty() && line.back() == '\r') line.pop_back();
      if (line.empty()) continue;

      LogLine("<- " + line);
      const bool is_shutdown = line.find("\"shutdown\"") != std::string::npos;
      std::string response = Dispatch(line);
      LogLine("-> " + response);
      if (!SendAll(client, response + "\n")) return;
      if (is_shutdown && response.find("\"ok\":true") != std::string::npos) {
        *shutdown_requested = true;
        return;
      }
    }
  }
}

int RunServer() {
  WSADATA wsa;
  if (WSAStartup(MAKEWORD(2, 2), &wsa) != 0) {
    fprintf(stderr, "WSAStartup gagal\n");
    return 1;
  }
  SOCKET listener = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
  if (listener == INVALID_SOCKET) {
    fprintf(stderr, "socket() gagal\n");
    WSACleanup();
    return 1;
  }
  BOOL yes = TRUE;
  setsockopt(listener, IPPROTO_TCP, TCP_NODELAY, reinterpret_cast<char*>(&yes),
             sizeof(yes));

  sockaddr_in addr = {};
  addr.sin_family = AF_INET;
  addr.sin_port = htons(static_cast<u_short>(g_config.port));
  inet_pton(AF_INET, "127.0.0.1", &addr.sin_addr);

  if (bind(listener, reinterpret_cast<sockaddr*>(&addr), sizeof(addr)) ==
      SOCKET_ERROR) {
    fprintf(stderr, "bind ke 127.0.0.1:%d gagal (%d)\n", g_config.port,
            WSAGetLastError());
    closesocket(listener);
    WSACleanup();
    return 1;
  }
  if (listen(listener, 4) == SOCKET_ERROR) {
    fprintf(stderr, "listen gagal (%d)\n", WSAGetLastError());
    closesocket(listener);
    WSACleanup();
    return 1;
  }

  // Baris siap-pakai untuk induk proses (Flutter) supaya tahu helper hidup.
  printf("{\"event\":\"listening\",\"port\":%d}\n", g_config.port);
  fflush(stdout);

  bool shutdown_requested = false;
  while (!shutdown_requested) {
    SOCKET client = accept(listener, nullptr, nullptr);
    if (client == INVALID_SOCKET) break;
    setsockopt(client, IPPROTO_TCP, TCP_NODELAY, reinterpret_cast<char*>(&yes),
               sizeof(yes));
    LogLine("klien terhubung");
    ServeClient(client, &shutdown_requested);
    closesocket(client);
    LogLine("klien terputus");
  }

  closesocket(listener);
  WSACleanup();
  return 0;
}

void PrintUsage() {
  printf(
      "sony_camera_helper - SnapTechBooth\n"
      "\n"
      "Mode:\n"
      "  --serve                 jalankan server socket (default)\n"
      "  --list                  daftar kamera WIA lalu keluar\n"
      "  --selftest              connect, satu capture, disconnect, lalu keluar\n"
      "\n"
      "Opsi:\n"
      "  --port <n>              port loopback (default 45455)\n"
      "  --out-dir <dir>         folder default hasil jepretan\n"
      "  --device-id <id>        pilih kamera berdasarkan WIA device id\n"
      "  --device-name <teks>    pilih kamera berdasarkan potongan nama\n"
      "  --token <rahasia>       wajibkan field token pada tiap perintah\n"
      "  --af-mode <mode>        require | prefer | skip (default require)\n"
      "  --af-timeout <ms>       batas tunggu status AF (default 5000)\n"
      "  --capture-timeout <ms>  batas tunggu berkas hasil (default 20000)\n"
      "  --poll-interval <ms>    jeda antar pembacaan status (default 40)\n"
      "  --s2-hold <ms>          durasi tahan tombol rana (default 200)\n"
      "  --command-timeout <ms>  batas satu perintah (default 60000)\n"
      "  --verbose               log ke stderr\n");
}

int RunSelfTest() {
  std::string out = Dispatch("{\"cmd\":\"list\"}");
  printf("%s\n", out.c_str());
  out = Dispatch("{\"cmd\":\"connect\"}");
  printf("%s\n", out.c_str());
  if (out.find("\"ok\":true") == std::string::npos) return 2;
  out = Dispatch("{\"cmd\":\"status\"}");
  printf("%s\n", out.c_str());
  out = Dispatch("{\"cmd\":\"capture\"}");
  printf("%s\n", out.c_str());
  const bool captured = out.find("\"ok\":true") != std::string::npos;
  std::string bye = Dispatch("{\"cmd\":\"disconnect\"}");
  printf("%s\n", bye.c_str());
  return captured ? 0 : 3;
}

}  // namespace

int main(int argc, char** argv) {
  enum class Mode { kServe, kList, kSelfTest } mode = Mode::kServe;

  for (int i = 1; i < argc; ++i) {
    const std::string a = argv[i];
    auto next = [&](const char* name) -> std::string {
      if (i + 1 >= argc) {
        fprintf(stderr, "opsi %s butuh nilai\n", name);
        exit(64);
      }
      return argv[++i];
    };
    if (a == "--help" || a == "-h") { PrintUsage(); return 0; }
    else if (a == "--serve") mode = Mode::kServe;
    else if (a == "--list") mode = Mode::kList;
    else if (a == "--selftest") mode = Mode::kSelfTest;
    else if (a == "--port") g_config.port = atoi(next("--port").c_str());
    else if (a == "--out-dir") g_config.out_dir = next("--out-dir");
    else if (a == "--device-id") g_config.device_id = Utf8ToWide(next("--device-id"));
    else if (a == "--device-name") g_config.device_name = Utf8ToWide(next("--device-name"));
    else if (a == "--token") g_config.token = next("--token");
    else if (a == "--af-timeout") g_config.capture.af_timeout_ms = atoi(next("--af-timeout").c_str());
    else if (a == "--capture-timeout") g_config.capture.capture_timeout_ms = atoi(next("--capture-timeout").c_str());
    else if (a == "--poll-interval") g_config.capture.poll_interval_ms = atoi(next("--poll-interval").c_str());
    else if (a == "--s2-hold") g_config.capture.s2_hold_ms = atoi(next("--s2-hold").c_str());
    else if (a == "--command-timeout") g_config.command_timeout_ms = atoi(next("--command-timeout").c_str());
    else if (a == "--verbose") g_config.verbose = true;
    else if (a == "--af-mode") {
      const std::string m = next("--af-mode");
      if (m == "require") g_config.capture.af_mode = AfMode::kRequire;
      else if (m == "prefer") g_config.capture.af_mode = AfMode::kPrefer;
      else if (m == "skip") g_config.capture.af_mode = AfMode::kSkip;
      else { fprintf(stderr, "--af-mode tidak dikenal: %s\n", m.c_str()); return 64; }
    } else {
      fprintf(stderr, "opsi tidak dikenal: %s\n", a.c_str());
      PrintUsage();
      return 64;
    }
  }

  if (!StartWorker()) {
    fprintf(stderr, "gagal memulai thread kamera\n");
    return 1;
  }

  int rc = 0;
  switch (mode) {
    case Mode::kList: {
      std::string out = Dispatch("{\"cmd\":\"list\"}");
      printf("%s\n", out.c_str());
      break;
    }
    case Mode::kSelfTest:
      rc = RunSelfTest();
      break;
    case Mode::kServe:
      rc = RunServer();
      break;
  }

  StopWorker();
  return rc;
}
