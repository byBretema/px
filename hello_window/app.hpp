#pragma once

#define yyEnable_Aliases
#define yyLib_Glm
#include "../vendor/y.hpp"

#include "window.hpp"

// #include "../vk/renderer.hpp"

// #include "base.hpp"
// #include "renderer.hpp"
// #include "camera.hpp"
// #include "userInput.hpp"

namespace px
{

enum RenderAPI
{
    Vulkan,
    // WebGpu,
    // Metal,
    // DX12,
    // OpenGL,
};

class App
{
public:
    App(std::string name, RenderAPI renderAPI);

    std::string name() const;
    void        runLoop();
    bool        isMarkedToClose() const;

private:
    friend class Window;

    void run();
    void reset();
    void cleanup();
    void markToClose();

    std::string mName      = "";
    RenderAPI   mRenderAPI = RenderAPI::Vulkan;

    bool mInit  = false;
    bool mClose = false;

    Sptr<px::Window>  mMainWindow = nullptr;
    // bm::BaseRenderer *mRenderer   = nullptr;

    // std::vector<Camera> mCameras = { sDefaultCamera };
    y::ElapsedTimer mETimer;

    // clang-format off
    // UserInput mUserInput { [this](UserInput *ui) { if (ui) for (auto &camera : mCameras) camera.onInputChange(*ui); } };
    // clang-format on

    // inline static Camera const sDefaultCamera { "Main" };
};

}  // namespace bm
