#include "app.hpp"

namespace px
{

App::App(std::string name, RenderAPI renderAPI) : mName(std::move(name)), mRenderAPI(renderAPI)
{
    y_info("Initializing the engine");

    // y_abort_if(
      // mMainWindow || mRenderer,
      // "Initialization fiasco... Window({}) or Renderer({}) already exists!",
      // BM_STR_PTR(mMainWindow),
      // BM_STR_PTR(mRenderer));

    // Init window
    // mMainWindow = sNew<Window>(1920, 1080, "Default Window", this);

    // Init renderer
    // switch (mRenderAPI)
    // {
        // case Vulkan: mRenderer = new vk::Renderer(mMainWindow); break;
        // default: BM_ABORT("Selected renderer is not implemented yet!"); break;
    // }
}

void App::runLoop()
{
    while (true)
    {
        run();
        cleanup();

        if (isMarkedToClose())
        {
            y_info("Closing the engine");
            break;
        }

        reset();
    }
}

void App::run()
{
    bool isAnyWindowOpen = true;  // NOTE: In a future we'll support many windows at once

    while (isAnyWindowOpen)
    {
        isAnyWindowOpen = false;

        for (auto &window : { mMainWindow })
        {
            //--- FPS
            std::string et = mETimer.elapsed_str_ms();
            window->titleInfo(et);
            mETimer.reset();
            //---

            //--- Update
            // mRenderer->update();

            // for (auto &camera : mCameras)
            // {
                // camera.update(1.77777f, INF3);
            // }
            //---

            //--- Draw
            // auto const &mainCamera = mCameras.at(0);
            // mRenderer->draw(mainCamera);
            //---

            //--- Close
            bool const close = window->isMarkedToClose();

            if (close)
            {
                // WARNING : This should trigger something on 'SelectedRenderer' ??
                window->destroy();
            }

            isAnyWindowOpen |= !close;
            //---
        }

        // bm::Window::waitEvents();  // WARNING: Prefer this one!
        px::Window::pollEvents();
    }
}

void App::cleanup()
{
    // mRenderer->cleanup();
    px::Window::terminate();

    // delete mRenderer;
    // mRenderer = nullptr;
}

void App::reset()
{
    *this = { mName, mRenderAPI };
}

std::string App::name() const
{
    return mName;
}

void App::markToClose()
{
    mClose = true;
}
bool App::isMarkedToClose() const
{
    return mClose;
}

}  // namespace bm
