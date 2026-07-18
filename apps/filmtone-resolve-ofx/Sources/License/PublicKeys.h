#pragma once

#include <cstddef>

// Ed25519 raw public keys embedded in the product (public information; the
// private keys never ship here — see monetization/implementation-plan.md §2).
//
// Lists are rotation-ready: on rotation a new key is prepended and the retired
// key is kept until every license issued under it has expired, then removed
// (scripts/license/README.md). Source of these values: the MON-3 keygen output
// recorded in monetization/progress.md (public-key hex is public).
//
// The `kind` signed into each license selects which list may verify it, so a
// leaked trial key can never mint anything that verifies as `full`.

namespace filmtone::resolve::license {

// 64 lowercase hex chars = 32 raw bytes each. LicenseStore decodes these once.
inline constexpr const char* kFullPublicKeysHex[] = {
    "4b887963416f325a290203b086caf40d811dd7724252f780f3c15fbfe7fdd376",
};

inline constexpr const char* kTrialPublicKeysHex[] = {
    "39af05f555ecdf06702470a09b2c0384e0ff34457b25f148fa98ee0e232fa4e0",
};

inline constexpr std::size_t kFullPublicKeyCount =
    sizeof(kFullPublicKeysHex) / sizeof(kFullPublicKeysHex[0]);
inline constexpr std::size_t kTrialPublicKeyCount =
    sizeof(kTrialPublicKeysHex) / sizeof(kTrialPublicKeysHex[0]);

}  // namespace filmtone::resolve::license
