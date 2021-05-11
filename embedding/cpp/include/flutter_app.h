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

  bool IsRunning() { return handle != nullptr; }

  FlutterDesktopPluginRegistrarRef GetRegistrarForPlugin(
      const std::string &plugin_name) override;

  // The switches to pass to the Flutter engine.
  // Custom switches may be added before `OnCreate` is called.
  std::vector<std::string> engine_args;

  // The Flutter engine instance handle.
  FlutterDesktopEngineRef handle;

 protected:
  void ParseEngineArgs();
};

#endif /* FLUTTER_TIZEN_EMBEDDING_CPP_INCLUDE_FLUTTER_APP_H_ */
