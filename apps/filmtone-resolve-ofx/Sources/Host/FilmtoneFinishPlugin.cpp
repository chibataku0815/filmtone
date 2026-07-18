#include <cmath>
#include <memory>
#include <optional>
#include <string>

#include "MetalIdentityBlit.h"
#include "MetalPipelineCache.h"
#include "RenderContext.h"
#include "ofxsImageEffect.h"
#include "ofxsLog.h"

namespace filmtone::resolve::host {
namespace {

constexpr char kPluginName[] = "Filmtone Finish";
constexpr char kPluginGrouping[] = "Filmtone";
constexpr char kPluginIdentifier[] = "com.chibatakumi.filmtone.finish";
constexpr int kPluginVersionMajor = 0;
constexpr int kPluginVersionMinor = 1;

RectI makeRect(const OfxRectI& rect) {
    return RectI{rect.x1, rect.y1, rect.x2, rect.y2};
}

bool isFloatRGBA(const OFX::Image& image) {
    return image.getPixelDepth() == OFX::eBitDepthFloat &&
           image.getPixelComponents() == OFX::ePixelComponentRGBA;
}

class FilmtoneFinishEffect final : public OFX::ImageEffect {
public:
    explicit FilmtoneFinishEffect(OfxImageEffectHandle handle)
        : OFX::ImageEffect(handle),
          outputClip_(fetchClip(kOfxImageEffectOutputClipName)),
          sourceClip_(fetchClip(kOfxImageEffectSimpleSourceClipName)) {}

    void render(const OFX::RenderArguments& args) override {
        if (!args.isEnabledMetalRender || args.pMetalCmdQ == nullptr) {
            OFX::throwSuiteStatusException(kOfxStatErrUnsupported);
        }

        std::unique_ptr<OFX::Image> output(outputClip_->fetchImage(args.time));
        std::unique_ptr<OFX::Image> source(sourceClip_->fetchImage(args.time));
        if (!output || !source) {
            OFX::throwSuiteStatusException(kOfxStatFailed);
        }
        if (!isFloatRGBA(*source) || !isFloatRGBA(*output)) {
            OFX::throwSuiteStatusException(kOfxStatErrUnsupported);
        }

        const double sourceFrameRate = sourceClip_->getFrameRate();
        const double timelineFrameRate = getFrameRate();
        if (!std::isfinite(sourceFrameRate) || sourceFrameRate <= 0.0 ||
            !std::isfinite(timelineFrameRate) || timelineFrameRate <= 0.0) {
            OFX::throwSuiteStatusException(kOfxStatErrValue);
        }

        const RenderContext context{
            args.time,
            FrameRates{sourceFrameRate, timelineFrameRate},
            std::nullopt,
            PointD{args.renderScale.x, args.renderScale.y},
            makeRect(args.renderWindow),
            makeRect(source->getBounds()),
            makeRect(output->getBounds()),
        };
        const MetalRenderInvocation invocation{
            args.pMetalCmdQ,
            MetalImageView{
                source->getPixelData(),
                source->getRowBytes(),
                makeRect(source->getBounds()),
                PixelFormat::floatRGBA,
            },
            MetalImageView{
                output->getPixelData(),
                output->getRowBytes(),
                makeRect(output->getBounds()),
                PixelFormat::floatRGBA,
            },
        };

        std::string error;
        if (!encodeMetalIdentityBlit(context, invocation, error)) {
            OFX::Log::error(true, "Filmtone Finish identity render failed: %s", error.c_str());
            OFX::throwSuiteStatusException(kOfxStatFailed);
        }
    }

    bool isIdentity(
        const OFX::IsIdentityArguments& args,
        OFX::Clip*& identityClip,
        double& identityTime) override {
        identityClip = sourceClip_;
        identityTime = args.time;
        return true;
    }

private:
    OFX::Clip* outputClip_;
    OFX::Clip* sourceClip_;
};

class FilmtoneFinishFactory final
    : public OFX::PluginFactoryHelper<FilmtoneFinishFactory> {
public:
    FilmtoneFinishFactory()
        : OFX::PluginFactoryHelper<FilmtoneFinishFactory>(
              kPluginIdentifier,
              kPluginVersionMajor,
              kPluginVersionMinor) {}

    void load() override {}
    void unload() override { MetalPipelineCache::shared().clear(); }

    void describe(OFX::ImageEffectDescriptor& descriptor) override {
        descriptor.setLabels(kPluginName, kPluginName, kPluginName);
        descriptor.setPluginGrouping(kPluginGrouping);
        descriptor.setPluginDescription(kPluginName);
        descriptor.addSupportedContext(OFX::eContextFilter);
        descriptor.addSupportedBitDepth(OFX::eBitDepthFloat);

        descriptor.setSingleInstance(false);
        descriptor.setHostFrameThreading(false);
        descriptor.setSupportsMultiResolution(true);
        descriptor.setSupportsTiles(false);
        descriptor.setTemporalClipAccess(false);
        descriptor.setRenderTwiceAlways(false);
        descriptor.setSupportsMultipleClipDepths(false);
        descriptor.setSupportsMultipleClipPARs(false);
        descriptor.setRenderThreadSafety(OFX::eRenderInstanceSafe);
        descriptor.setSupportsMetalRender(true);
        descriptor.setNoSpatialAwareness(false);
    }

    void describeInContext(
        OFX::ImageEffectDescriptor& descriptor,
        OFX::ContextEnum) override {
        OFX::ClipDescriptor* source =
            descriptor.defineClip(kOfxImageEffectSimpleSourceClipName);
        source->addSupportedComponent(OFX::ePixelComponentRGBA);
        source->setTemporalClipAccess(false);
        source->setSupportsTiles(false);
        source->setIsMask(false);

        OFX::ClipDescriptor* output =
            descriptor.defineClip(kOfxImageEffectOutputClipName);
        output->addSupportedComponent(OFX::ePixelComponentRGBA);
        output->setSupportsTiles(false);
    }

    OFX::ImageEffect* createInstance(
        OfxImageEffectHandle handle,
        OFX::ContextEnum) override {
        return new FilmtoneFinishEffect(handle);
    }
};

}  // namespace

void appendPluginFactory(OFX::PluginFactoryArray& factories) {
    static FilmtoneFinishFactory factory;
    factories.push_back(&factory);
}

}  // namespace filmtone::resolve::host

void OFX::Plugin::getPluginIDs(PluginFactoryArray& factories) {
    filmtone::resolve::host::appendPluginFactory(factories);
}
