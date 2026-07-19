#import <Foundation/Foundation.h>

#include <cstdio>

#include "LicenseStore.h"

// MON-2 cross-verification harness (C++ side). Runs each vector from vectors.json
// through LicenseStore::evaluateBytes() and compares its verdict to the TS
// core.ts verdict recorded by gen_vectors.ts. Exit 0 iff every vector matches.
//
// Built and run by run.sh; see that script for the compile line.

using filmtone::resolve::license::LicenseState;
using filmtone::resolve::license::LicenseStatus;
using filmtone::resolve::license::LicenseStore;

static const char* statusStr(LicenseStatus s) {
  switch (s) {
    case LicenseStatus::Unlicensed: return "unlicensed";
    case LicenseStatus::Licensed: return "licensed";
    case LicenseStatus::Trial: return "trial";
    case LicenseStatus::Expired: return "expired";
    case LicenseStatus::Invalid: return "invalid";
  }
  return "?";
}

int main(int argc, const char* argv[]) {
  @autoreleasepool {
    NSString* path = argc > 1 ? [NSString stringWithUTF8String:argv[1]] : @"vectors.json";
    NSData* data = [NSData dataWithContentsOfFile:path];
    if (data == nil) {
      fprintf(stderr, "cannot read %s\n", path.UTF8String);
      return 2;
    }
    NSArray* vectors = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    if (![vectors isKindOfClass:[NSArray class]]) {
      fprintf(stderr, "vectors.json is not an array\n");
      return 2;
    }

    int pass = 0;
    int fail = 0;
    for (NSDictionary* v in vectors) {
      NSString* name = v[@"name"];
      NSString* envelope = v[@"envelope"];
      long long nowMs = [v[@"nowMs"] longLongValue];
      NSString* expected = v[@"tsStatus"];

      NSData* envBytes = [envelope dataUsingEncoding:NSUTF8StringEncoding];
      LicenseState st = LicenseStore::evaluateBytes(
          static_cast<const unsigned char*>(envBytes.bytes), envBytes.length, nowMs / 1000);
      const char* got = statusStr(st.status);
      bool ok = [expected isEqualToString:[NSString stringWithUTF8String:got]];
      printf("%-30s ts=%-10s cpp=%-10s %s\n",
             name.UTF8String, expected.UTF8String, got, ok ? "PASS" : "FAIL  <<<<");
      if (ok) {
        ++pass;
      } else {
        ++fail;
      }
    }
    printf("\n%d PASS, %d FAIL / %lu vectors\n", pass, fail, static_cast<unsigned long>(vectors.count));
    return fail == 0 ? 0 : 1;
  }
}
