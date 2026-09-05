#include "json_min.h"

#include <cstdio>

namespace stb {

std::string JsonEscape(const std::string& in) {
  std::string out;
  out.reserve(in.size() + 8);
  for (unsigned char c : in) {
    switch (c) {
      case '"': out += "\\\""; break;
      case '\\': out += "\\\\"; break;
      case '\b': out += "\\b"; break;
      case '\f': out += "\\f"; break;
      case '\n': out += "\\n"; break;
      case '\r': out += "\\r"; break;
      case '\t': out += "\\t"; break;
      default:
        if (c < 0x20) {
          char buf[8];
          snprintf(buf, sizeof(buf), "\\u%04x", c);
          out += buf;
        } else {
          out += static_cast<char>(c);
        }
    }
  }
  return out;
}

void JsonWriter::Sep() {
  if (first_) {
    os_ << '{';
    first_ = false;
  } else {
    os_ << ',';
  }
}

JsonWriter& JsonWriter::Bool(const std::string& key, bool value) {
  Sep();
  os_ << '"' << JsonEscape(key) << "\":" << (value ? "true" : "false");
  return *this;
}

JsonWriter& JsonWriter::Int(const std::string& key, long long value) {
  Sep();
  os_ << '"' << JsonEscape(key) << "\":" << value;
  return *this;
}

JsonWriter& JsonWriter::UInt(const std::string& key, unsigned long long value) {
  Sep();
  os_ << '"' << JsonEscape(key) << "\":" << value;
  return *this;
}

JsonWriter& JsonWriter::Str(const std::string& key, const std::string& value) {
  Sep();
  os_ << '"' << JsonEscape(key) << "\":\"" << JsonEscape(value) << '"';
  return *this;
}

JsonWriter& JsonWriter::Raw(const std::string& key,
                            const std::string& raw_value) {
  Sep();
  os_ << '"' << JsonEscape(key) << "\":" << raw_value;
  return *this;
}

std::string JsonWriter::Done() {
  if (first_) return "{}";
  os_ << '}';
  return os_.str();
}

namespace {

void SkipWs(const std::string& s, size_t* i) {
  while (*i < s.size() && (s[*i] == ' ' || s[*i] == '\t' || s[*i] == '\r' ||
                           s[*i] == '\n')) {
    ++(*i);
  }
}

bool ParseString(const std::string& s, size_t* i, std::string* out) {
  if (*i >= s.size() || s[*i] != '"') return false;
  ++(*i);
  out->clear();
  while (*i < s.size()) {
    char c = s[*i];
    if (c == '"') {
      ++(*i);
      return true;
    }
    if (c == '\\') {
      ++(*i);
      if (*i >= s.size()) return false;
      char e = s[*i];
      switch (e) {
        case '"': *out += '"'; break;
        case '\\': *out += '\\'; break;
        case '/': *out += '/'; break;
        case 'b': *out += '\b'; break;
        case 'f': *out += '\f'; break;
        case 'n': *out += '\n'; break;
        case 'r': *out += '\r'; break;
        case 't': *out += '\t'; break;
        case 'u': {
          if (*i + 4 >= s.size()) return false;
          unsigned code = 0;
          for (int k = 1; k <= 4; ++k) {
            char h = s[*i + k];
            unsigned d;
            if (h >= '0' && h <= '9') d = h - '0';
            else if (h >= 'a' && h <= 'f') d = h - 'a' + 10;
            else if (h >= 'A' && h <= 'F') d = h - 'A' + 10;
            else return false;
            code = code * 16 + d;
          }
          *i += 4;
          if (code < 0x80) {
            *out += static_cast<char>(code);
          } else if (code < 0x800) {
            *out += static_cast<char>(0xC0 | (code >> 6));
            *out += static_cast<char>(0x80 | (code & 0x3F));
          } else {
            *out += static_cast<char>(0xE0 | (code >> 12));
            *out += static_cast<char>(0x80 | ((code >> 6) & 0x3F));
            *out += static_cast<char>(0x80 | (code & 0x3F));
          }
          break;
        }
        default:
          return false;
      }
      ++(*i);
      continue;
    }
    *out += c;
    ++(*i);
  }
  return false;
}

bool ParseBareValue(const std::string& s, size_t* i, std::string* out) {
  const size_t start = *i;
  while (*i < s.size() && s[*i] != ',' && s[*i] != '}') ++(*i);
  size_t end = *i;
  while (end > start && (s[end - 1] == ' ' || s[end - 1] == '\t')) --end;
  if (end == start) return false;
  *out = s.substr(start, end - start);
  return true;
}

}  // namespace

bool JsonParseFlat(const std::string& text,
                   std::map<std::string, std::string>* out) {
  out->clear();
  size_t i = 0;
  SkipWs(text, &i);
  if (i >= text.size() || text[i] != '{') return false;
  ++i;
  SkipWs(text, &i);
  if (i < text.size() && text[i] == '}') return true;

  for (;;) {
    SkipWs(text, &i);
    std::string key;
    if (!ParseString(text, &i, &key)) return false;
    SkipWs(text, &i);
    if (i >= text.size() || text[i] != ':') return false;
    ++i;
    SkipWs(text, &i);
    std::string value;
    if (i < text.size() && text[i] == '"') {
      if (!ParseString(text, &i, &value)) return false;
    } else {
      if (!ParseBareValue(text, &i, &value)) return false;
    }
    (*out)[key] = value;
    SkipWs(text, &i);
    if (i < text.size() && text[i] == ',') {
      ++i;
      continue;
    }
    if (i < text.size() && text[i] == '}') return true;
    return false;
  }
}

}  // namespace stb
