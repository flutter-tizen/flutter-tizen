// Copyright 2021 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef FLUTTER_TIZEN_EMBEDDING_CPP_INCLUDE_FLUTTER_APP_H_
#define FLUTTER_TIZEN_EMBEDDING_CPP_INCLUDE_FLUTTER_APP_H_

#include <app.h>
#include <flutter/plugin_registry.h>
#include <flutter_tizen.h>

#include <memory>
#include <string>
#include <vector>

#include "flutter_engine.h"

enum class FlutterRendererType {
  // The renderer based on EvasGL.
  kEvasGL,
  // The renderer based on EGL.
  kEGL,
};

enum class FlutterExternalOutputType {
  // No use external output.
  kNone,
  // Display to the HDMI external output.
  kHDMI,
};

// The app base class for headed Flutter execution.
class FlutterApp : public flutter::PluginRegistry {
 public:
  explicit FlutterApp() {
#ifdef WEARABLE_PROFILE
    renderer_type_ = FlutterRendererType::kEvasGL;
#endif
  }
  virtual ~FlutterApp() {}

  // Called when the app is starting.
  //
  // Invoking this method implicitly initializes |engine_| and |view_|.
  // Any method that overrides this method must invoke this method.
  virtual bool OnCreate();

  // Called when the app becomes visible to the user.
  virtual void OnResume();

  // Called when the app becomes invisible to the user.
  virtual void OnPause();

  // Called when the app is terminating.
  virtual void OnTerminate();

  // Called when an app control message has been received.
  virtual void OnAppControlReceived(app_control_h app_control);

  // Called when the system is running out of memory.
  virtual void OnLowMemory(app_event_info_h event_info);

  // Called when the device is running out of battery.
  virtual void OnLowBattery(app_event_info_h event_info) {}

  // Called when the system language has changed.
  virtual void OnLanguageChanged(app_event_info_h event_info);

  // Called when the system region format has changed.
  virtual void OnRegionFormatChanged(app_event_info_h event_info);

  // Called when the device orientation has changed.
  virtual void OnDeviceOrientationChanged(app_event_info_h event_info) {}

  // Runs the main loop of the app.
  virtual int Run(int argc, char **argv);

  // Whether the app has started.
  bool IsRunning() { return view_ != nullptr; }

  void SetDartEntrypoint(const std::string &entrypoint) {
    dart_entrypoint_ = entrypoint;
  }

  // |flutter::PluginRegistry|
  FlutterDesktopPluginRegistrarRef GetRegistrarForPlugin(
      const std::string &plugin_name) override;

 protected:
  // The x-coordinate of the top left corner of the window.
  int32_t window_offset_x_ = 0;

  // The y-coordinate of the top left corner of the window.
  int32_t window_offset_y_ = 0;

  // The width of the window.
  //
  // Defaults to the screen width if the value is zero.
  int32_t window_width_ = 0;

  // The height of the window.
  //
  // Defaults to the screen height if the value is zero.
  int32_t window_height_ = 0;

  // Whether the window should have a transparent background or not.
  bool is_window_transparent_ = false;

  // Whether the window should be focusable or not.
  bool is_window_focusable_ = true;

  // Whether the app should be displayed over other apps.
  //
  // If true, the "http://tizen.org/privilege/window.priority.set" privilege
  // must be added to tizen-manifest.xml file.
  bool is_top_level_ = false;

  // The renderer type of the engine.
  //
  // Defaults to kEGL. If the profile is wearable, defaults to kEvasGL.
  FlutterRendererType renderer_type_ = FlutterRendererType::kEGL;

  // The external output type of the engine.
  //
  // Defaults to kNone.
  FlutterExternalOutputType external_output_type_ =
      FlutterExternalOutputType::kNone;

 private:
  // The optional entrypoint in the Dart project.
  //
  // Defaults to main() if the value is empty.
  std::string dart_entrypoint_;

  // The Flutter engine instance.
  std::unique_ptr<FlutterEngine> engine_;

  // The Flutter view instance handle.
  FlutterDesktopViewRef view_ = nullptr;
};

#endif /* FLUTTER_TIZEN_EMBEDDING_CPP_INCLUDE_FLUTTER_APP_H_ */
