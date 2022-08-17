// Copyright 2021 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef FLUTTER_TIZEN_EMBEDDING_CPP_INCLUDE_FLUTTER_SERVICE_APP_H_
#define FLUTTER_TIZEN_EMBEDDING_CPP_INCLUDE_FLUTTER_SERVICE_APP_H_

#include <flutter/plugin_registry.h>
#include <flutter_tizen.h>
#include <service_app.h>

#include <memory>
#include <string>
#include <vector>

#include "flutter_engine.h"

// The app base class for headless Flutter execution.
class FlutterServiceApp : public flutter::PluginRegistry {
 public:
  explicit FlutterServiceApp() {}
  virtual ~FlutterServiceApp() {}

  // Called when the app is starting.
  //
  // Invoking this method implicitly initializes |engine_|.
  // Any method that overrides this method must invoke this method.
  virtual bool OnCreate();

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

  // Runs the main loop of the app.
  virtual int Run(int argc, char **argv);

  // Whether the app has started.
  bool IsRunning() { return engine_ != nullptr; }

  void SetDartEntrypoint(const std::string &entrypoint) {
    dart_entrypoint_ = entrypoint;
  }

  // |flutter::PluginRegistry|
  FlutterDesktopPluginRegistrarRef GetRegistrarForPlugin(
      const std::string &plugin_name) override;

 private:
  // The optional entrypoint in the Dart project.
  //
  // Defaults to main() if the value is empty.
  std::string dart_entrypoint_;

  // The list of Dart entrypoint arguments.
  std::vector<std::string> dart_entrypoint_args_;

  // The Flutter engine instance.
  std::unique_ptr<FlutterEngine> engine_;
};

#endif /* FLUTTER_TIZEN_EMBEDDING_CPP_INCLUDE_FLUTTER_SERVICE_APP_H_ */
