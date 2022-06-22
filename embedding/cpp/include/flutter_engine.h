// Copyright 2022 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef FLUTTER_TIZEN_EMBEDDING_CPP_INCLUDE_FLUTTER_ENGINE_H_
#define FLUTTER_TIZEN_EMBEDDING_CPP_INCLUDE_FLUTTER_ENGINE_H_

#include <flutter/plugin_registry.h>
#include <flutter_tizen.h>

#include <string>
#include <vector>

// The engine for flutter execution
class FlutterEngine : public flutter::PluginRegistry {
 public:
  FlutterEngine(const std::string& assets_path,
                const std::string& icu_data_path,
                const std::string& aot_library_path,
                const std::vector<std::string>& engine_arguments,
                const std::string& dart_entrypoint,
                const std::vector<std::string>& dart_entrypoint_arguments);
  virtual ~FlutterEngine();

  // Prevent copying.
  FlutterEngine(FlutterEngine const&) = delete;
  FlutterEngine& operator=(FlutterEngine const&) = delete;

  // Starts running the engine.
  bool Run();

  // Terminates the running engine.
  void Shutdown();

  // Whether the engine is running.
  bool IsRunning() { return is_running_; }

  // Resumes the engine.
  //
  // This method notifies the running Flutter app that it is "resumed" as per
  // the Flutter app lifecycle.
  void Resume();

  // Pauses the engine.
  //
  // This method notifies the running Flutter app that it is "inactive" as per
  // the Flutter app lifecycle.
  void Pause();

  // Stops the engine.
  //
  // This method notifies the running Flutter app that it is "paused" as per
  // the Flutter app lifecycle.
  void Stop();

  // Detaches the engine.
  //
  // This method notifies the running Flutter app that it is "detached" as per
  // the Flutter app lifecycle.
  void Detache();

  // Notifies that the host app received an app control.
  //
  // This method sends the app control to Flutter over the "app control event
  // channel"
  void NotifyAppControl(void* app_control);

  // Notifies that low memory warning.
  //
  // This method sends a "memory pressure warning" message to Flutter over the
  // "system channel"
  void NotifyLowMemoryWarning();

  // Notifies that the locale has changed.
  //
  // This method sends a "memory pressure warning" message to Flutter
  void NotifyLocaleChange();

  FlutterDesktopPluginRegistrarRef GetRegistrarForPlugin(
      const std::string& plugin_name) override;

 private:
  std::string assets_path_;
  std::string icu_data_path_;
  std::string aot_library_path_;
  std::vector<std::string> engine_arguments_;
  std::string dart_entrypoint_;
  std::vector<std::string> dart_entrypoint_arguments_;

  // Handle for interacting with the C API's engine reference.
  FlutterDesktopEngineRef engine_ = nullptr;
  bool is_running_ = false;
};

#endif /* FLUTTER_TIZEN_EMBEDDING_CPP_INCLUDE_FLUTTER_ENGINE_H_ */
