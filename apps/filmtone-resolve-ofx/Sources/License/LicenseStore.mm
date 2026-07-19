#import <Foundation/Foundation.h>

#include <cstring>
#include <ctime>

#include "LicenseStore.h"
#include "PublicKeys.h"
#include "vendor/ed25519/ed25519.h"

// This file ports scripts/license/core.ts to the OFX product. The signed bytes
// are the payload bytes carried verbatim in the file, so verification never
// re-canonicalizes before checking the signature. The strict canonical-form
// check (parse -> re-canonicalize -> byte-equal) rejects duplicate/reordered/
// unknown keys and inserted whitespace, matching decodePayloadStrict().

namespace filmtone::resolve::license {
namespace {

constexpr const char* kSchema = "filmtone-license/1";
constexpr const char* kProduct = "com.chibatakumi.filmtone.resolve";
constexpr const char* kEdition = "v1";
constexpr int kTrialMaxDays = 31;
constexpr long long kIssuedAtClockSkewSec = 3LL * 86400LL;
constexpr std::size_t kMaxPayloadBytes = 4096;
constexpr std::size_t kMaxLicenseFileBytes = 16384;
constexpr NSUInteger kNameMaxChars = 120;
constexpr NSUInteger kEmailMaxChars = 254;
constexpr NSUInteger kOrderRefMaxChars = 120;

// JSON.stringify-compatible escaping of a single string (with surrounding
// quotes). Non-ASCII passes through as UTF-8; control chars use the short forms
// or lowercase \u00xx, exactly like the reference implementation.
NSString* escapeJsonString(NSString* s) {
  NSMutableString* out = [NSMutableString stringWithCapacity:s.length + 2];
  [out appendString:@"\""];
  NSUInteger n = s.length;
  for (NSUInteger i = 0; i < n; ++i) {
    unichar c = [s characterAtIndex:i];
    switch (c) {
      case '"': [out appendString:@"\\\""]; break;
      case '\\': [out appendString:@"\\\\"]; break;
      case 0x08: [out appendString:@"\\b"]; break;
      case 0x09: [out appendString:@"\\t"]; break;
      case 0x0A: [out appendString:@"\\n"]; break;
      case 0x0C: [out appendString:@"\\f"]; break;
      case 0x0D: [out appendString:@"\\r"]; break;
      default:
        if (c < 0x20) {
          [out appendFormat:@"\\u%04x", c];
        } else {
          [out appendFormat:@"%C", c];
        }
    }
  }
  [out appendString:@"\""];
  return out;
}

// Mirrors canonicalize() in core.ts: sorted keys, no whitespace, JSON.stringify
// semantics. Valid payloads are flat objects of strings (+ expiresAt null);
// other value types only appear in adversarial inputs and are rejected by the
// structural checks that follow.
NSString* canonicalize(id v) {
  if (v == nil || v == [NSNull null]) return @"null";
  if ([v isKindOfClass:[NSString class]]) return escapeJsonString((NSString*)v);
  if ([v isKindOfClass:[NSNumber class]]) {
    NSNumber* n = (NSNumber*)v;
    if (CFGetTypeID((__bridge CFTypeRef)n) == CFBooleanGetTypeID()) {
      return [n boolValue] ? @"true" : @"false";
    }
    const char* t = [n objCType];
    if (strcmp(t, @encode(double)) == 0 || strcmp(t, @encode(float)) == 0) {
      return [NSString stringWithFormat:@"%.17g", [n doubleValue]];
    }
    return [NSString stringWithFormat:@"%lld", [n longLongValue]];
  }
  if ([v isKindOfClass:[NSArray class]]) {
    NSMutableArray<NSString*>* parts = [NSMutableArray array];
    for (id e in (NSArray*)v) [parts addObject:canonicalize(e)];
    return [NSString stringWithFormat:@"[%@]", [parts componentsJoinedByString:@","]];
  }
  if ([v isKindOfClass:[NSDictionary class]]) {
    NSDictionary* d = (NSDictionary*)v;
    NSArray* keys = [[d allKeys] sortedArrayUsingComparator:^NSComparisonResult(id a, id b) {
      return [(NSString*)a compare:(NSString*)b options:NSLiteralSearch];
    }];
    NSMutableArray<NSString*>* parts = [NSMutableArray array];
    for (id k in keys) {
      NSString* ks = [k isKindOfClass:[NSString class]] ? (NSString*)k : [k description];
      [parts addObject:[NSString stringWithFormat:@"%@:%@", escapeJsonString(ks),
                                                   canonicalize(d[k])]];
    }
    return [NSString stringWithFormat:@"{%@}", [parts componentsJoinedByString:@","]];
  }
  return @"null";
}

// Strict RFC 3339 UTC seconds form (YYYY-MM-DDThh:mm:ssZ) that round-trips
// exactly, matching parseIsoStrict(). Rejects impossible dates (e.g. Feb 30).
bool parseIsoStrict(id value, long long* outUnix) {
  if (![value isKindOfClass:[NSString class]]) return false;
  NSString* s = (NSString*)value;
  if (s.length != 20) return false;
  const char* c = s.UTF8String;
  if (c == nullptr) return false;
  auto dig = [](char ch) { return ch >= '0' && ch <= '9'; };
  if (!(dig(c[0]) && dig(c[1]) && dig(c[2]) && dig(c[3]))) return false;
  if (c[4] != '-') return false;
  if (!(dig(c[5]) && dig(c[6]))) return false;
  if (c[7] != '-') return false;
  if (!(dig(c[8]) && dig(c[9]))) return false;
  if (c[10] != 'T') return false;
  if (!(dig(c[11]) && dig(c[12]))) return false;
  if (c[13] != ':') return false;
  if (!(dig(c[14]) && dig(c[15]))) return false;
  if (c[16] != ':') return false;
  if (!(dig(c[17]) && dig(c[18]))) return false;
  if (c[19] != 'Z') return false;
  if (c[20] != '\0') return false;
  int year = (c[0] - '0') * 1000 + (c[1] - '0') * 100 + (c[2] - '0') * 10 + (c[3] - '0');
  int mon = (c[5] - '0') * 10 + (c[6] - '0');
  int day = (c[8] - '0') * 10 + (c[9] - '0');
  int hh = (c[11] - '0') * 10 + (c[12] - '0');
  int mm = (c[14] - '0') * 10 + (c[15] - '0');
  int ss = (c[17] - '0') * 10 + (c[18] - '0');
  struct tm tm;
  std::memset(&tm, 0, sizeof(tm));
  tm.tm_year = year - 1900;
  tm.tm_mon = mon - 1;
  tm.tm_mday = day;
  tm.tm_hour = hh;
  tm.tm_min = mm;
  tm.tm_sec = ss;
  time_t t = timegm(&tm);
  if (t == static_cast<time_t>(-1)) return false;
  struct tm back;
  gmtime_r(&t, &back);
  if (back.tm_year != year - 1900 || back.tm_mon != mon - 1 || back.tm_mday != day ||
      back.tm_hour != hh || back.tm_min != mm || back.tm_sec != ss) {
    return false;
  }
  *outUnix = static_cast<long long>(t);
  return true;
}

bool hexKeyToBytes(const char* hex, unsigned char out[32]) {
  if (hex == nullptr) return false;
  for (int i = 0; i < 32; ++i) {
    auto nibble = [](char ch, int* v) -> bool {
      if (ch >= '0' && ch <= '9') { *v = ch - '0'; return true; }
      if (ch >= 'a' && ch <= 'f') { *v = ch - 'a' + 10; return true; }
      return false;
    };
    int hi = 0, lo = 0;
    if (!nibble(hex[i * 2], &hi) || !nibble(hex[i * 2 + 1], &lo)) return false;
    out[i] = static_cast<unsigned char>((hi << 4) | lo);
  }
  return hex[64] == '\0';
}

// Non-empty after JS-.trim()-equivalent whitespace stripping.
bool nonEmptyTrimmed(NSString* s) {
  NSString* t = [s stringByTrimmingCharactersInSet:
                       [NSCharacterSet whitespaceAndNewlineCharacterSet]];
  return t.length > 0;
}

NSString* requireString(NSDictionary* d, NSString* key) {
  id v = d[key];
  return [v isKindOfClass:[NSString class]] ? (NSString*)v : nil;
}

}  // namespace

std::string LicenseState::statusLine() const {
  switch (status) {
    case LicenseStatus::Licensed:
      return "Licensed to " + name;
    case LicenseStatus::Trial: {
      std::string day = expiresAt.size() >= 10 ? expiresAt.substr(0, 10) : expiresAt;
      return "Trial — expires " + day;
    }
    default:
      return "Trial mode (watermarked)";
  }
}

LicenseStore::Base LicenseStore::verifyBytesToBase(const unsigned char* data,
                                                   std::size_t len, long long nowUnix) {
  Base base;
  if (data == nullptr || len == 0 || len > kMaxLicenseFileBytes) {
    base.kind = Base::Kind::Invalid;
    return base;
  }
  @autoreleasepool {
    NSData* fileData = [NSData dataWithBytes:data length:len];
    id envObj = [NSJSONSerialization JSONObjectWithData:fileData options:0 error:nil];
    if (![envObj isKindOfClass:[NSDictionary class]]) {
      base.kind = Base::Kind::Invalid;
      return base;
    }
    NSDictionary* env = (NSDictionary*)envObj;
    // Envelope: exactly {schema, payload, sig}.
    if (env.count != 3 || ![requireString(env, @"schema") isEqualToString:@(kSchema)] ||
        requireString(env, @"payload") == nil || requireString(env, @"sig") == nil) {
      base.kind = Base::Kind::Invalid;
      return base;
    }
    NSData* payloadData = [[[NSData alloc]
        initWithBase64EncodedString:requireString(env, @"payload") options:0] autorelease];
    NSData* sigData = [[[NSData alloc]
        initWithBase64EncodedString:requireString(env, @"sig") options:0] autorelease];
    if (payloadData == nil || sigData == nil) {
      base.kind = Base::Kind::Invalid;
      return base;
    }
    if (payloadData.length == 0 || payloadData.length > kMaxPayloadBytes ||
        sigData.length != 64) {
      base.kind = Base::Kind::Invalid;
      return base;
    }

    // Strict payload decode.
    id parsed = [NSJSONSerialization JSONObjectWithData:payloadData options:0 error:nil];
    if (![parsed isKindOfClass:[NSDictionary class]]) {
      base.kind = Base::Kind::Invalid;
      return base;
    }
    NSDictionary* p = (NSDictionary*)parsed;
    // Exactly the 9 signed fields must be present. The canonical-form check
    // below additionally rejects any byte-level deviation (dup/reorder/space).
    if (p.count != 9 || p[@"edition"] == nil || p[@"email"] == nil ||
        p[@"expiresAt"] == nil || p[@"issuedAt"] == nil || p[@"kind"] == nil ||
        p[@"name"] == nil || p[@"orderRef"] == nil || p[@"product"] == nil ||
        p[@"schema"] == nil) {
      base.kind = Base::Kind::Invalid;
      return base;
    }
    // Canonical-form equality against the exact signed bytes.
    NSData* canon = [canonicalize(p) dataUsingEncoding:NSUTF8StringEncoding];
    if (canon.length != payloadData.length ||
        std::memcmp(canon.bytes, payloadData.bytes, canon.length) != 0) {
      base.kind = Base::Kind::Invalid;
      return base;
    }

    // structuralError() port.
    if (![requireString(p, @"schema") isEqualToString:@(kSchema)] ||
        ![requireString(p, @"product") isEqualToString:@(kProduct)] ||
        ![requireString(p, @"edition") isEqualToString:@(kEdition)]) {
      base.kind = Base::Kind::Invalid;
      return base;
    }
    NSString* kind = requireString(p, @"kind");
    bool isFull = [kind isEqualToString:@"full"];
    bool isTrial = [kind isEqualToString:@"trial"];
    if (!isFull && !isTrial) {
      base.kind = Base::Kind::Invalid;
      return base;
    }
    NSString* name = requireString(p, @"name");
    NSString* email = requireString(p, @"email");
    NSString* orderRef = requireString(p, @"orderRef");
    if (name == nil || !nonEmptyTrimmed(name) || name.length > kNameMaxChars ||
        email == nil || !nonEmptyTrimmed(email) || email.length > kEmailMaxChars ||
        orderRef == nil || !nonEmptyTrimmed(orderRef) || orderRef.length > kOrderRefMaxChars) {
      base.kind = Base::Kind::Invalid;
      return base;
    }
    long long issuedUnix = 0;
    if (!parseIsoStrict(p[@"issuedAt"], &issuedUnix)) {
      base.kind = Base::Kind::Invalid;
      return base;
    }
    long long expiresUnix = 0;
    if (isFull) {
      if (p[@"expiresAt"] != [NSNull null]) {
        base.kind = Base::Kind::Invalid;
        return base;
      }
    } else {
      if (!parseIsoStrict(p[@"expiresAt"], &expiresUnix)) {
        base.kind = Base::Kind::Invalid;
        return base;
      }
      if (expiresUnix <= issuedUnix ||
          (expiresUnix - issuedUnix) > static_cast<long long>(kTrialMaxDays) * 86400LL) {
        base.kind = Base::Kind::Invalid;
        return base;
      }
    }

    // Kind-bound Ed25519 verification.
    const char* const* keyHexList = isFull ? kFullPublicKeysHex : kTrialPublicKeysHex;
    std::size_t keyCount = isFull ? kFullPublicKeyCount : kTrialPublicKeyCount;
    bool signatureOk = false;
    for (std::size_t i = 0; i < keyCount && !signatureOk; ++i) {
      unsigned char pub[32];
      if (!hexKeyToBytes(keyHexList[i], pub)) continue;
      if (ed25519_verify(static_cast<const unsigned char*>(sigData.bytes),
                         static_cast<const unsigned char*>(payloadData.bytes),
                         payloadData.length, pub) == 1) {
        signatureOk = true;
      }
    }
    if (!signatureOk) {
      base.kind = Base::Kind::Invalid;
      return base;
    }

    base.name = name.UTF8String ? name.UTF8String : "";
    if (isFull) {
      base.kind = Base::Kind::Full;
      return base;
    }
    // Trial: reject issuedAt beyond the clock-skew tolerance.
    if (issuedUnix > nowUnix + kIssuedAtClockSkewSec) {
      base.kind = Base::Kind::Invalid;
      return base;
    }
    base.kind = Base::Kind::Trial;
    NSString* expiresStr = requireString(p, @"expiresAt");
    base.expiresIso = expiresStr.UTF8String ? expiresStr.UTF8String : "";
    base.expiresUnix = expiresUnix;
    return base;
  }
}

LicenseState LicenseStore::deriveFromBase(const Base& base, long long nowUnix) {
  LicenseState state;
  switch (base.kind) {
    case Base::Kind::None:
      state.status = LicenseStatus::Unlicensed;
      break;
    case Base::Kind::Invalid:
      state.status = LicenseStatus::Invalid;
      break;
    case Base::Kind::Full:
      state.status = LicenseStatus::Licensed;
      state.name = base.name;
      break;
    case Base::Kind::Trial:
      state.status = base.expiresUnix <= nowUnix ? LicenseStatus::Expired
                                                 : LicenseStatus::Trial;
      state.name = base.name;
      state.expiresAt = base.expiresIso;
      break;
  }
  return state;
}

LicenseState LicenseStore::evaluateBytes(const unsigned char* data, std::size_t len,
                                         long long nowUnix) {
  return deriveFromBase(verifyBytesToBase(data, len, nowUnix), nowUnix);
}

namespace {

NSString* licenseFilePath() {
  NSArray<NSString*>* dirs = NSSearchPathForDirectoriesInDomains(
      NSApplicationSupportDirectory, NSUserDomainMask, YES);
  NSString* appSupport = dirs.count > 0 ? dirs.firstObject
                                        : [NSHomeDirectory()
                                              stringByAppendingPathComponent:
                                                  @"Library/Application Support"];
  return [appSupport stringByAppendingPathComponent:@"Filmtone/Filmtone.license"];
}

}  // namespace

void LicenseStore::reloadLocked(long long nowUnix) {
  @autoreleasepool {
    NSString* path = licenseFilePath();
    NSFileManager* fm = [NSFileManager defaultManager];
    NSDictionary* attrs = [fm attributesOfItemAtPath:path error:nil];
    if (attrs == nil) {
      // No file (or unreadable) -> unlicensed.
      base_ = Base{};
      cachedMtime_ = 0;
      cachedSize_ = -1;
      return;
    }
    long long mtime =
        static_cast<long long>([(NSDate*)attrs[NSFileModificationDate] timeIntervalSince1970]);
    long long size = static_cast<long long>([(NSNumber*)attrs[NSFileSize] longLongValue]);
    if (loadedOnce_ && mtime == cachedMtime_ && size == cachedSize_) {
      return;  // unchanged since last read
    }
    cachedMtime_ = mtime;
    cachedSize_ = size;
    NSData* fileData = [NSData dataWithContentsOfFile:path];
    if (fileData == nil) {
      base_ = Base{};
      return;
    }
    base_ = verifyBytesToBase(static_cast<const unsigned char*>(fileData.bytes),
                              fileData.length, nowUnix);
  }
}

LicenseState LicenseStore::evaluate() {
  long long now = static_cast<long long>(::time(nullptr));
  std::lock_guard<std::mutex> lock(mutex_);
  if (!loadedOnce_ || (now - lastStatUnix_) >= kThrottleSeconds) {
    lastStatUnix_ = now;
    reloadLocked(now);
    loadedOnce_ = true;
  }
  return deriveFromBase(base_, now);
}

LicenseState LicenseStore::refreshNow() {
  long long now = static_cast<long long>(::time(nullptr));
  std::lock_guard<std::mutex> lock(mutex_);
  lastStatUnix_ = now;
  cachedMtime_ = 0;
  cachedSize_ = -1;  // force a real reload
  reloadLocked(now);
  loadedOnce_ = true;
  return deriveFromBase(base_, now);
}

LicenseStore& LicenseStore::shared() {
  static LicenseStore instance;
  return instance;
}

}  // namespace filmtone::resolve::license
