#pragma once

#if __APPLE__
#    define GLFW_EXPOSE_NATIVE_COCOA
#elif _WIN64 || _WIN32
#    define GLFW_EXPOSE_NATIVE_WIN32
#elif __linux || __unix || __posix
#    define GLFW_EXPOSE_NATIVE_X11
// #  define GLFW_EXPOSE_NATIVE_WAYLAND
#endif

// #include <y.hpp>
#define yyEnable_Aliases
#define yyLib_Glm
#include "../vendor/y.hpp"

#define GLFW_INCLUDE_NONE
#include <GLFW/glfw3.h>
#include <GLFW/glfw3native.h>

namespace px
{

class App;

class Window
{
public:
    Window(i32 w, i32 h, std::string const &title, App *app);

    void        destroy();
    static void pollEvents();
    static void waitEvents();
    static void terminate();

    void *handle() const;
    bool  isMarkedToClose() const;

    inline std::string title() const { return mTitle; }
    void               title(std::string title);
    void               titleInfo(std::string info);

    vec2 size() const;
    void      size(i32 w, i32 h);

    inline bool focus() { return mFocus; }
    inline void focus(bool f) { mFocus = f; }

    static inline std::vector<char const *> extensions() { return sExtensions; }

private:
    void refreshTitle();

    GLFWwindow *mHandle = nullptr;

    i32 mW = 1280;
    i32 mH = 720;

    std::string mTitle     = "";
    std::string mTitleInfo = "";

    bool mFocus = false;

    static inline std::vector<char const *> sExtensions                 = {};
    static inline bool                      sIsWindowContextInitialized = false;
};

}  // namespace px
