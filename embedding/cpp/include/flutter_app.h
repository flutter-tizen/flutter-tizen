// Copyright 2021 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef FLUTTER_TIZEN_EMBEDDING_CPP_INCLUDE_FLUTTER_APP_H_
#define FLUTTER_TIZEN_EMBEDDING_CPP_INCLUDE_FLUTTER_APP_H_

#include <app.h>
#include <flutter/plugin_registry.h>
#include <flutter_tizen.h>

#include <string>
#include <vector>

// The app base class which creates and manages the Flutter engine instance.
class FlutterApp : public flutter::PluginRegistry {
 public:
  explicit FlutterApp() {}
  virtual ~FlutterApp() {}

  virtual bool OnCreate();

  virtual void OnResume();

  virtual void OnPause();

  virtual void OnTerminate();

  virtual void OnAppControlReceived(app_control_h app_control) {}

  virtual void OnLowMemory(app_event_info_h event_info);

  virtual void OnLowBattery(app_event_info_h event_info) {}

  virtual void OnLanguageChanged(app_event_info_h event_info);

  virtual void OnRegionFormatChanged(app_event_info_h event_info);

  virtual void OnDeviceOrientationChanged(app_event_info_h event_info) {}

  virtual int Run(int argc, char **argv);

  bool IsRunning() { return handle_ != nullptr; }

  FlutterDesktopPluginRegistrarRef GetRegistrarForPlugin(
      const std::string &plugin_name) override;

 protected:
  void ParseEngineArgs();

  // Whether the app is headed or headless.
  bool is_headed_ = true;

  // The x-coordinate of the top left corner of the window.
  int32_t window_offset_x_ = 0;

  // The y-coordinate of the top left corner of the window.
  int32_t window_offset_y_ = 0;

  // The width of the window, or the maximum width if the value is zero.
  int32_t window_width_ = 0;

  // The height of the window, or the maximum height if the value is zero.
  int32_t window_height_ = 0;

  // Whether the window should have a transparent background or not.
  bool is_window_transparent_ = false;

  // Whether the window should be focusable or not.
  bool is_window_focusable_ = true;

  // The switches to pass to the Flutter engine.
  // Custom switches may be added before `OnCreate` is called.
  std::vector<std::string> engine_args_;

  // The optional entrypoint in the Dart project. If the value is empty,
  // defaults to main().
  std::string dart_entrypoint_;

  // The list of Dart entrypoint arguments.
  std::vector<std::string> dart_entrypoint_args_;

  // The Flutter engine instance handle.
  FlutterDesktopEngineRef handle_;
};

#endif /* FLUTTER_TIZEN_EMBEDDING_CPP_INCLUDE_FLUTTER_APP_H_ */
