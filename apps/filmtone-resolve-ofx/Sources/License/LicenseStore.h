#pragma once

#include <cstddef>
#include <mutex>
#include <string>

// Offline license evaluation for the Filmtone OFX product. No network code:
// the license is a signed file the user drops next to the app support folder.
// Behavior mirrors the TypeScript reference scripts/license/core.ts exactly
// (envelope, strict canonical decode, kind-bound Ed25519 verification, trial
// clock-skew + expiry). See monetization/implementation-plan.md §2/§3.

namespace filmtone::resolve::license {

enum class LicenseStatus {
  Unlicensed,  // no license file present -> watermark
  Licensed,    // valid full license -> clean
  Trial,       // valid trial, not yet expired -> clean
  Expired,     // valid trial, past expiry -> watermark
  Invalid,     // file present but not a valid license -> watermark
};

struct LicenseState {
  LicenseStatus status = LicenseStatus::Unlicensed;
  std::string name;        // "Licensed to <name>" (full)
  std::string expiresAt;   // ISO UTC; "Trial — expires YYYY-MM-DD" (trial)

  // True when the trial watermark must be composited: anything other than a
  // valid full license or an active (non-expired) trial.
  [[nodiscard]] bool watermarked() const noexcept {
    return status != LicenseStatus::Licensed && status != LicenseStatus::Trial;
  }

  // Read-only line for the License parameter group.
  [[nodiscard]] std::string statusLine() const;
};

// Process-wide, thread-safe, network-free license evaluator.
//
// evaluate() runs on the render path: it returns an immutable snapshot and only
// re-reads the license file when stat(mtime+size) shows a change, throttled to
// at most one stat per kThrottleSeconds. The trial expiry transition is derived
// from the current wall clock on every call (no file read needed). refreshNow()
// forces an immediate stat + reload for UI / instanceChanged updates.
class LicenseStore {
 public:
  static constexpr long long kThrottleSeconds = 5;

  static LicenseStore& shared();

  LicenseState evaluate();    // render path: cheap, cached
  LicenseState refreshNow();  // forces stat + reload (UI refresh)

  // Pure evaluator over raw license-file bytes at a given wall clock (seconds
  // since epoch). Exposed for cross-verification against core.ts. Never touches
  // the filesystem.
  static LicenseState evaluateBytes(const unsigned char* data, std::size_t len,
                                    long long nowUnix);

  LicenseStore(const LicenseStore&) = delete;
  LicenseStore& operator=(const LicenseStore&) = delete;

 private:
  LicenseStore() = default;

  // Verified, time-independent essentials cached between reads. Trial vs Expired
  // is derived from the current clock in evaluate(), not stored here.
  struct Base {
    enum class Kind { None, Invalid, Full, Trial } kind = Kind::None;
    std::string name;
    std::string expiresIso;
    long long expiresUnix = 0;
  };

  // Envelope + strict decode + kind-bound Ed25519 verification, producing the
  // time-independent Base (the trial issuedAt clock-skew check uses nowUnix).
  static Base verifyBytesToBase(const unsigned char* data, std::size_t len,
                                long long nowUnix);
  // Maps a verified Base to a status at the given wall clock (trial expiry).
  static LicenseState deriveFromBase(const Base& base, long long nowUnix);

  void reloadLocked(long long nowUnix);

  std::mutex mutex_;
  Base base_;
  bool loadedOnce_ = false;
  long long lastStatUnix_ = 0;
  long long cachedMtime_ = 0;
  long long cachedSize_ = -1;
};

}  // namespace filmtone::resolve::license
