// Utilitas JSON minimal (objek datar saja) supaya helper tidak butuh
// dependensi eksternal.
#pragma once

#include <map>
#include <sstream>
#include <string>

namespace stb {

std::string JsonEscape(const std::string& in);

class JsonWriter {
 public:
  JsonWriter& Bool(const std::string& key, bool value);
  JsonWriter& Int(const std::string& key, long long value);
  JsonWriter& UInt(const std::string& key, unsigned long long value);
  JsonWriter& Str(const std::string& key, const std::string& value);
  JsonWriter& Raw(const std::string& key, const std::string& raw_value);
  std::string Done();

 private:
  void Sep();
  std::ostringstream os_;
  bool first_ = true;
};

// Parser objek datar: {"a":"b","c":1,"d":true}
// Semua nilai dikembalikan sebagai string.
bool JsonParseFlat(const std::string& text,
                   std::map<std::string, std::string>* out);

}  // namespace stb
