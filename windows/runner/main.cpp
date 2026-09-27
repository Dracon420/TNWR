#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
#if !defined(_DEBUG)
  // One copy at a time: a second launch (e.g. from the Start menu while the
  // app sits in the tray) brings the running copy forward instead of starting
  // another, which would make every alarm ring twice. Debug builds skip this
  // so `flutter run` works next to an installed copy.
  HANDLE single_instance =
      ::CreateMutexW(nullptr, TRUE, L"Local\\TNWR-single-instance");
  if (single_instance && ::GetLastError() == ERROR_ALREADY_EXISTS) {
    // The login autostart (--minimized) stays quiet; a user launch shows it.
    if (!wcsstr(command_line, L"--minimized")) {
      HWND running =
          ::FindWindowW(L"FLUTTER_RUNNER_WIN32_WINDOW", L"T.N.W.R.");
      if (running) {
        ::ShowWindow(running, SW_SHOW);
        ::ShowWindow(running, SW_RESTORE);
        ::SetForegroundWindow(running);
      }
    }
    return EXIT_SUCCESS;
  }
#endif

  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"T.N.W.R.", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
