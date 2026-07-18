#import <Metal/Metal.h>

#include "MetalPipelineCache.h"

#include <mutex>
#include <utility>
#include <vector>

namespace filmtone::resolve::host {
namespace {

std::string describeError(NSError* error, const char* fallback) {
    if (error != nil && error.localizedDescription != nil) {
        const char* description = error.localizedDescription.UTF8String;
        if (description != nullptr) {
            return description;
        }
    }
    return fallback;
}

}  // namespace

class MetalPipelineCache::Impl final {
public:
    ~Impl() { clear(); }

    void* getOrCreate(
        void* commandQueue,
        const MetalPipelineRequest& request,
        std::string& error) {
        if (commandQueue == nullptr) {
            error = "Metal command queue is missing.";
            return nullptr;
        }
        if (request.cacheKey.empty() || request.librarySource.empty() || request.functionName.empty()) {
            error = "Metal pipeline request is incomplete.";
            return nullptr;
        }

        id<MTLCommandQueue> queue = static_cast<id<MTLCommandQueue>>(commandQueue);
        id<MTLDevice> device = queue.device;
        if (device == nil) {
            error = "Metal command queue has no device.";
            return nullptr;
        }

        std::lock_guard<std::mutex> lock(mutex_);
        void* deviceKey = static_cast<void*>(device);
        for (const Entry& entry : entries_) {
            if (entry.device == deviceKey && entry.cacheKey == request.cacheKey) {
                if (entry.librarySource != request.librarySource ||
                    entry.functionName != request.functionName ||
                    entry.fastMathEnabled != request.fastMathEnabled) {
                    error = "Metal pipeline cache key collision.";
                    return nullptr;
                }
                return entry.pipeline;
            }
        }

        MTLCompileOptions* options = [[MTLCompileOptions alloc] init];
        options.fastMathEnabled = request.fastMathEnabled ? YES : NO;

        NSError* libraryError = nil;
        NSString* source = [NSString stringWithUTF8String:request.librarySource.c_str()];
        id<MTLLibrary> library = [device newLibraryWithSource:source options:options error:&libraryError];
        [options release];
        if (library == nil) {
            error = describeError(libraryError, "Metal library compilation failed.");
            return nullptr;
        }

        NSString* functionName = [NSString stringWithUTF8String:request.functionName.c_str()];
        id<MTLFunction> function = [library newFunctionWithName:functionName];
        if (function == nil) {
            [library release];
            error = "Metal function was not found in the compiled library.";
            return nullptr;
        }

        NSError* pipelineError = nil;
        id<MTLComputePipelineState> pipeline =
            [device newComputePipelineStateWithFunction:function error:&pipelineError];
        [function release];
        [library release];
        if (pipeline == nil) {
            error = describeError(pipelineError, "Metal pipeline creation failed.");
            return nullptr;
        }

        entries_.push_back(Entry{
            deviceKey,
            request.cacheKey,
            request.librarySource,
            request.functionName,
            request.fastMathEnabled,
            static_cast<void*>(pipeline),
        });
        return static_cast<void*>(pipeline);
    }

    void clear() {
        std::lock_guard<std::mutex> lock(mutex_);
        for (const Entry& entry : entries_) {
            id<MTLComputePipelineState> pipeline =
                static_cast<id<MTLComputePipelineState>>(entry.pipeline);
            [pipeline release];
        }
        entries_.clear();
    }

private:
    struct Entry final {
        void* device;
        std::string cacheKey;
        std::string librarySource;
        std::string functionName;
        bool fastMathEnabled;
        void* pipeline;
    };

    std::mutex mutex_;
    std::vector<Entry> entries_;
};

MetalPipelineCache& MetalPipelineCache::shared() {
    static MetalPipelineCache cache;
    return cache;
}

MetalPipelineCache::MetalPipelineCache()
    : impl_(std::make_unique<Impl>()) {}

MetalPipelineCache::~MetalPipelineCache() = default;

void* MetalPipelineCache::getOrCreate(
    void* commandQueue,
    const MetalPipelineRequest& request,
    std::string& error) {
    return impl_->getOrCreate(commandQueue, request, error);
}

void MetalPipelineCache::clear() {
    impl_->clear();
}

}  // namespace filmtone::resolve::host
