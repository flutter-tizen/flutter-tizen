// Copyright 2021 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef FLUTTER_TIZEN_EMBEDDING_CPP_INCLUDE_FLUTTER_SERVICE_APP_H_
#define FLUTTER_TIZEN_EMBEDDING_CPP_INCLUDE_FLUTTER_SERVICE_APP_H_

#include <service_app.h>

#include <flutter/plugin_registry.h>
#include <flutter_tizen.h>

#include <string>
#include <vector>

// The app base class for headless execution.
class FlutterServiceApp : public flutter::PluginRegistry {
 public:
  explicit FlutterServiceApp() {}
  virtual ~FlutterServiceApp() {}

  virtual bool OnCreate();

  virtual void OnTerminate();

  virtual void OnAppControlReceived(app_control_h app_control);

  virtual void OnLowMemory(app_event_info_h event_info);

  virtual void OnLowBattery(app_event_info_h event_info) {}

  virtual void OnLanguageChanged(app_event_info_h event_info);

  virtual void OnRegionFormatChanged(app_event_info_h event_info);

  virtual void OnDeviceOrientationChanged(app_event_info_h event_info) {}

  virtual int Run(int argc, char **argv);

  FlutterDesktopPluginRegistrarRef GetRegistrarForPlugin(
      const std::string &plugin_name) override;

  bool IsRunning() { return engine_ != nullptr; }

  void SetDartEntrypoint(const std::string &entrypoint) {
    dart_entrypoint_ = entrypoint;
  }

 protected:
  // The switches to pass to the Flutter engine.
  // Custom switches may be added before `OnCreate` is called.
  std::vector<std::string> engine_args_;

  // The optional entrypoint in the Dart project. If the value is empty,
  // defaults to main().
  std::string dart_entrypoint_;

  // The list of Dart entrypoint arguments.
  std::vector<std::string> dart_entrypoint_args_;

  // The Flutter engine instance handle.
  FlutterDesktopEngineRef engine_ = nullptr;
};

#endif /* FLUTTER_TIZEN_EMBEDDING_CPP_INCLUDE_FLUTTER_SERVICE_APP_H_ */
