#include <cstdint>
#include <memory>
#include <string>

#include "../Integration/FilmtoneParameters.h"
#include "../Integration/FilmtoneRenderGraph.h"
#include "../License/LicenseStore.h"
#include "MetalPipelineCache.h"
#include "RenderContext.h"
#include "ofxsImageEffect.h"
#include "ofxsLog.h"

namespace filmtone::resolve::host {
namespace {

constexpr char kPluginName[] = "Filmtone";
constexpr char kPluginGrouping[] = "Filmtone";
constexpr char kPluginIdentifier[] = "com.chibatakumi.filmtone.resolve";
constexpr char kPluginDescription[] =
    "Adds deterministic Film Breath, Gate Weave, and Film Damage. Apply "
    "Filmtone manually after CinePrint35 by default; the effect remains "
    "movable. When using CinePrint35, keep only one Gate Weave treatment and "
    "one Dust treatment enabled.";
constexpr int kPluginVersionMajor = 0;
constexpr int kPluginVersionMinor = 1;

RectI makeRect(const OfxRectI& rect) {
    return RectI{rect.x1, rect.y1, rect.x2, rect.y2};
}

bool isFloatRGBA(const OFX::Image& image) {
    return image.getPixelDepth() == OFX::eBitDepthFloat &&
           image.getPixelComponents() == OFX::ePixelComponentRGBA;
}

class FilmtoneEffect final : public OFX::ImageEffect {
public:
    explicit FilmtoneEffect(OfxImageEffectHandle handle)
        : OFX::ImageEffect(handle),
          outputClip_(fetchClip(kOfxImageEffectOutputClipName)),
          sourceClip_(fetchClip(kOfxImageEffectSimpleSourceClipName)),
          parameters_(*this) {}

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

        const auto evaluated = parameters_.evaluate(args.time);
        const double sourceFrameRate = sourceClip_->getFrameRate();
        const double timelineFrameRate = getFrameRate();
        const auto resolvedFrameRates = integration::resolveFrameRates(
            sourceFrameRate,
            timelineFrameRate);
        if (!resolvedFrameRates.has_value() &&
            !integration::isFilmtoneConfiguredIdentity(evaluated)) {
            OFX::throwSuiteStatusException(kOfxStatErrValue);
        }
        const FrameRates frameRates = resolvedFrameRates.has_value()
            ? *resolvedFrameRates
            : FrameRates{sourceFrameRate, timelineFrameRate};

        const RenderContext context{
            args.time,
            frameRates,
            static_cast<std::uint64_t>(evaluated.mapping().variation),
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
        if (!integration::encodeFilmtoneMetal(
                evaluated,
                context,
                invocation,
                MetalPipelineCache::shared(),
                error)) {
            OFX::Log::error(
                true,
                "Filmtone render failed: %s",
                error.c_str());
            OFX::throwSuiteStatusException(kOfxStatFailed);
        }
    }

    bool isIdentity(
        const OFX::IsIdentityArguments& args,
        OFX::Clip*& identityClip,
        double& identityTime) override {
        // A trial/unlicensed instance always composites a watermark on the final
        // output, so the effect is never a pass-through — even with every module
        // off. Report non-identity so the Host actually renders this frame.
        if (license::LicenseStore::shared().evaluate().watermarked()) {
            return false;
        }
        const auto evaluated = parameters_.evaluate(args.time);
        if (integration::isFilmtoneConfiguredIdentity(evaluated)) {
            identityClip = sourceClip_;
            identityTime = args.time;
            return true;
        }
        const auto frameRates = integration::resolveFrameRates(
            sourceClip_->getFrameRate(),
            getFrameRate());
        if (!frameRates.has_value()) {
            return false;
        }
        const RectI renderWindow = makeRect(args.renderWindow);
        const RenderContext context{
            args.time,
            *frameRates,
            static_cast<std::uint64_t>(evaluated.mapping().variation),
            PointD{args.renderScale.x, args.renderScale.y},
            renderWindow,
            renderWindow,
            renderWindow,
        };
        if (!integration::isFilmtoneIdentity(evaluated, context)) {
            return false;
        }
        identityClip = sourceClip_;
        identityTime = args.time;
        return true;
    }

private:
    OFX::Clip* outputClip_;
    OFX::Clip* sourceClip_;
    integration::FilmtoneParameterSet parameters_;
};

class FilmtoneFactory final
    : public OFX::PluginFactoryHelper<FilmtoneFactory> {
public:
    FilmtoneFactory()
        : OFX::PluginFactoryHelper<FilmtoneFactory>(
              kPluginIdentifier,
              kPluginVersionMajor,
              kPluginVersionMinor) {}

    void load() override {}
    void unload() override { MetalPipelineCache::shared().clear(); }

    void describe(OFX::ImageEffectDescriptor& descriptor) override {
        descriptor.setLabels(kPluginName, kPluginName, kPluginName);
        descriptor.setPluginGrouping(kPluginGrouping);
        descriptor.setPluginDescription(kPluginDescription);
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

        integration::describeFilmtoneParameters(descriptor);
    }

    OFX::ImageEffect* createInstance(
        OfxImageEffectHandle handle,
        OFX::ContextEnum) override {
        return new FilmtoneEffect(handle);
    }
};

}  // namespace

void appendPluginFactory(OFX::PluginFactoryArray& factories) {
    static FilmtoneFactory factory;
    factories.push_back(&factory);
}

}  // namespace filmtone::resolve::host

void OFX::Plugin::getPluginIDs(PluginFactoryArray& factories) {
    filmtone::resolve::host::appendPluginFactory(factories);
}
