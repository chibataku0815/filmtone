#pragma once

#include <memory>
#include <string>

namespace filmtone::resolve::host {

struct MetalPipelineRequest final {
    const std::string cacheKey;
    const std::string librarySource;
    const std::string functionName;
    const bool fastMathEnabled;
};

class MetalPipelineCache final {
public:
    static MetalPipelineCache& shared();

    ~MetalPipelineCache();

    MetalPipelineCache(const MetalPipelineCache&) = delete;
    MetalPipelineCache& operator=(const MetalPipelineCache&) = delete;

    void* getOrCreate(
        void* commandQueue,
        const MetalPipelineRequest& request,
        std::string& error);

    void clear();

private:
    class Impl;

    MetalPipelineCache();

    std::unique_ptr<Impl> impl_;
};

}  // namespace filmtone::resolve::host
