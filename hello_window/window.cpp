#include "window.hpp"

#include "app.hpp"

#include <stb_image.h>

namespace px
{

static void *sMainWindow = nullptr;

static Umap<void *, Window *> sHandleToWindow {};

App &detail_bm_app(GLFWwindow *handle)
{
    App *ptApp = ((App *)(glfwGetWindowUserPointer(handle)));
    y_assert(ptApp);
    return *ptApp;
}
Window &detail_win_self(GLFWwindow *handle)
{
    y_assert(sHandleToWindow.count(handle) > 0);
    Window *ptWin = sHandleToWindow[handle];
    y_assert(ptWin);
    return *ptWin;
}

#define SELF detail_win_self(p)
#define APP  detail_bm_app(p)
#define UI   detail_bm_app(p).mUserInput

Window::Window(i32 w, i32 h, std::string const &title, App *app) : mW(w), mH(h), mTitle(title)
{
    y_abort_if(app, "Window requires a valid App pointer");

    if (!sIsWindowContextInitialized)
    {
        y_abort_if(!glfwInit(), "Couldn't initialize Window-Manager");
        glfwWindowHint(GLFW_CLIENT_API, GLFW_NO_API);   // Avoid OpenGL context creation
        glfwWindowHint(GLFW_RESIZABLE, GLFW_TRUE);      // Resize windows takes special care
        glfwWindowHint(GLFW_FOCUS_ON_SHOW, GLFW_TRUE);  // Focus the window when its opened

        u32          extsCount = 0;
        char const **exts      = glfwGetRequiredInstanceExtensions(&extsCount);
        sExtensions            = exts ? decltype(sExtensions) { exts, exts + extsCount } : decltype(sExtensions) {};

        sIsWindowContextInitialized = true;
    }

    // Create window object
    mHandle = glfwCreateWindow(mW, mH, "", nullptr, nullptr);
    y_abort_if(!mHandle, "Couldn't create a new Window");

    // Add window icon
    auto const path = bm::runtime::exepath() + "/Assets/Icons/app.png";
    GLFWimage  img[1];
    img[0].pixels = stbi_load(path.c_str(), &img[0].width, &img[0].height, 0, 4);
    glfwSetWindowIcon(mHandle, 1, img);
    stbi_image_free(img[0].pixels);

    // Store app pointer into window object
    glfwSetWindowUserPointer(mHandle, app);

    // Store window handle to object relation
    sHandleToWindow[mHandle] = this;

    // Store main window object
    if (!sMainWindow)
        sMainWindow = mHandle;

    // clang-format off

    // Window Events
    // -- Resize
    // glfwSetFramebufferSizeCallback(mHandle, [](GLFWwindow *p, i32 w, i32 h) { SELF.size(w, h); });
    // -- Focus
    // glfwSetCursorEnterCallback(mHandle, [](GLFWwindow *p, i32 focus) { SELF.focus((bool)focus); });
    // -- On Close
    // glfwSetWindowCloseCallback(mHandle, [](GLFWwindow *p) { if (p == sMainWindow) APP.markToClose(); });

    // User-Input Events
    // -- Mouse
    // glfwSetMouseButtonCallback(mHandle, [](GLFWwindow *p, i32 m, i32 s, i32) { UI.click(m, s); });
    // glfwSetCursorPosCallback(mHandle, [](GLFWwindow *p, double x, double y) { UI.cursor({x, y}); });
    // glfwSetScrollCallback(mHandle, [](GLFWwindow *p, double x, double y) { UI.wheel({x, y}); });
    // -- Keyboard
    // glfwSetKeyCallback(mHandle, [](GLFWwindow *p, i32 k, i32, i32 s, i32) { UI.press(k, s); });

    // clang-format on

    refreshTitle();
}

bool Window::isMarkedToClose() const
{
    return mHandle ? glfwWindowShouldClose(mHandle) : true;
}
void Window::destroy()
{
    if (mHandle)
    {
        glfwDestroyWindow(mHandle);
        mHandle = nullptr;
    }
}
void Window::pollEvents()
{
    glfwPollEvents();
}
void Window::waitEvents()
{
    glfwWaitEvents();
}
void Window::terminate()
{
    sIsWindowContextInitialized = false;  // Ensures recreation of window-context after app/renderer 'cleanup'
    glfwTerminate();
}

vec2 Window::size() const
{
    return { mW, mH };
}
void Window::size(i32 w, i32 h)
{
    mW = w;
    mH = h;
}

void *Window::handle() const
{
    return mHandle;
}

void Window::refreshTitle()
{
    if (mHandle)
        glfwSetWindowTitle(mHandle, (detail_bm_app(mHandle).name() + " :: " + mTitle + " :: " + mTitleInfo).c_str());
}

void Window::title(std::string title)
{
    mTitle = std::move(title);
    refreshTitle();
}

void Window::titleInfo(std::string info)
{
    mTitleInfo = std::move(info);
    refreshTitle();
}

}  // namespace bm
