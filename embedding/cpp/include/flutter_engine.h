// Copyright 2022 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef FLUTTER_TIZEN_EMBEDDING_CPP_INCLUDE_FLUTTER_ENGINE_H_
#define FLUTTER_TIZEN_EMBEDDING_CPP_INCLUDE_FLUTTER_ENGINE_H_

#include <app_control.h>
#include <flutter/plugin_registry.h>
#include <flutter_tizen.h>

#include <algorithm>
#include <map>
#include <memory>
#include <string>
#include <vector>

#include "flutter_engine_arguments.h"

// The engine for Flutter execution.
class FlutterEngine : public flutter::PluginRegistry {
 public:
  virtual ~FlutterEngine();

  // Creates a |FlutterEngine| with an optional entrypoint name and entrypoint
  // arguments.
  //
  // |ui_thread_policy| controls which thread the UI isolate runs on. Defaults
  // to |FlutterDesktopUIThreadPolicy::kDefault|, which merges the UI isolate
  // onto the platform thread. If the UI isolate is blocked by a long-running
  // synchronous native call (e.g. via FFI), the platform thread can no
  // longer respond to the Tizen app framework (app control/resume
  // requests), which may cause the app to be killed by the platform
  // watchdog.
  //
  // |FlutterDesktopUIThreadPolicy::kRunOnSeparateThread| is available for
  // apps that need it, but apps must still make sure their Dart code never
  // blocks indefinitely, whichever policy is used. Apps that choose this
  // policy are responsible for any issues that result from doing so.
  static std::unique_ptr<FlutterEngine> Create(
      const std::string& dart_entrypoint = "",
      const std::vector<std::string>& dart_entrypoint_args = {},
      FlutterDesktopUIThreadPolicy ui_thread_policy =
          FlutterDesktopUIThreadPolicy::kDefault);

  // Creates a |FlutterEngine| with the given arguments.
  //
  // See the other |Create| overload for the meaning of |ui_thread_policy|.
  static std::unique_ptr<FlutterEngine> Create(
      const std::string& assets_path, const std::string& icu_data_path,
      const std::string& aot_library_path,
      const std::string& dart_entrypoint = "",
      const std::vector<std::string>& dart_entrypoint_args = {},
      FlutterDesktopUIThreadPolicy ui_thread_policy =
          FlutterDesktopUIThreadPolicy::kDefault);

  // Prevent copying.
  FlutterEngine(FlutterEngine const&) = delete;
  FlutterEngine& operator=(FlutterEngine const&) = delete;

  // Starts running the engine.
  bool Run();

  // Terminates the running engine.
  void Shutdown();

  // Notifies that the host app is visible and responding to user input.
  //
  // This method notifies the running Flutter app that it is "resumed" as per
  // the Flutter app lifecycle.
  void NotifyAppIsResumed();

  // Notifies that the host app is invisible and not responding to user input.
  //
  // This method notifies the running Flutter app that it is "paused" as per
  // the Flutter app lifecycle.
  void NotifyAppIsPaused();

  // Notifies that the engine is detached from any host views.
  //
  // This method notifies the running Flutter app that it is "detached" as per
  // the Flutter app lifecycle.
  void NotifyAppIsDetached();

  // Notifies that the host app received an app control.
  //
  // This method sends the app control to Flutter over the "app control event
  // channel".
  void NotifyAppControl(app_control_h app_control);

  // Notifies that a low memory warning has been received.
  //
  // This method sends a "memory pressure warning" message to Flutter over the
  // "system channel".
  void NotifyLowMemoryWarning();

  // Notifies that the system locale has changed.
  //
  // This method sends a "locale change" message to Flutter.
  void NotifyLocaleChange();

  // Gives up ownership of |engine_|, but keeps a weak reference to it.
  FlutterDesktopEngineRef RelinquishEngine();

  // |flutter::PluginRegistry|
  FlutterDesktopPluginRegistrarRef GetRegistrarForPlugin(
      const std::string& plugin_name) override;

  // The engine arguments instance containing parsed arguments and metadata
  // flags.
  const FlutterEngineArguments& GetArguments() const {
    return *engine_arguments_;
  }

 private:
  FlutterEngine(const std::string& assets_path,
                const std::string& icu_data_path,
                const std::string& aot_library_path,
                const std::string& dart_entrypoint,
                const std::vector<std::string>& dart_entrypoint_args,
                FlutterDesktopUIThreadPolicy ui_thread_policy);

  // Handle for interacting with the C API's engine reference.
  FlutterDesktopEngineRef engine_ = nullptr;

  // Whether or not this wrapper owns |engine_|.
  bool owns_engine_ = true;

  // The engine arguments instance.
  std::unique_ptr<FlutterEngineArguments> engine_arguments_;
};

#endif /* FLUTTER_TIZEN_EMBEDDING_CPP_INCLUDE_FLUTTER_ENGINE_H_ */
