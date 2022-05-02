// Copyright 2021 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "include/flutter_service_app.h"

#include <cassert>
#include <cerrno>

#include "tizen_log.h"
#include "utils.h"

bool FlutterServiceApp::OnCreate() {
  TizenLog::Debug("Launching a Flutter service application...");

  // Read engine arguments passed from the tool.
  Utils::ParseEngineArgs(&engine_args_);

  std::vector<const char *> switches;
  for (auto &arg : engine_args_) {
    switches.push_back(arg.c_str());
  }
  std::vector<const char *> entrypoint_args;
  for (auto &arg : dart_entrypoint_args_) {
    entrypoint_args.push_back(arg.c_str());
  }

  FlutterDesktopEngineProperties engine_prop = {};
  engine_prop.assets_path = "../res/flutter_assets";
  engine_prop.icu_data_path = "../res/icudtl.dat";
  engine_prop.aot_library_path = "../lib/libapp.so";
  engine_prop.switches = switches.data();
  engine_prop.switches_count = switches.size();
  engine_prop.entrypoint = dart_entrypoint_.c_str();
  engine_prop.dart_entrypoint_argc = entrypoint_args.size();
  engine_prop.dart_entrypoint_argv = entrypoint_args.data();

  engine_ = FlutterDesktopEngineCreate(engine_prop);
  if (!engine_) {
    TizenLog::Error("Could not create a Flutter engine.");
    return false;
  }
  if (!FlutterDesktopEngineRun(engine_)) {
    TizenLog::Error("Could not run a Flutter engine.");
    return false;
  }
  return true;
}

void FlutterServiceApp::OnTerminate() {
  assert(IsRunning());

  TizenLog::Debug("Shutting down the service application...");

  FlutterDesktopEngineShutdown(engine_);
  engine_ = nullptr;
}

void FlutterServiceApp::OnAppControlReceived(app_control_h app_control) {
  assert(IsRunning());

  FlutterDesktopEngineNotifyAppControl(engine_, app_control);
}

void FlutterServiceApp::OnLowMemory(app_event_info_h event_info) {
  assert(IsRunning());

  FlutterDesktopEngineNotifyLowMemoryWarning(engine_);
}

void FlutterServiceApp::OnLanguageChanged(app_event_info_h event_info) {
  assert(IsRunning());

  FlutterDesktopEngineNotifyLocaleChange(engine_);
}

void FlutterServiceApp::OnRegionFormatChanged(app_event_info_h event_info) {
  assert(IsRunning());

  FlutterDesktopEngineNotifyLocaleChange(engine_);
}

int FlutterServiceApp::Run(int argc, char **argv) {
  service_app_lifecycle_callback_s lifecycle_cb = {};
  lifecycle_cb.create = [](void *data) -> bool {
    auto *service_app = reinterpret_cast<FlutterServiceApp *>(data);
    return service_app->OnCreate();
  };
  lifecycle_cb.terminate = [](void *data) {
    auto *service_app = reinterpret_cast<FlutterServiceApp *>(data);
    service_app->OnTerminate();
  };
  lifecycle_cb.app_control = [](app_control_h a, void *data) {
    auto *service_app = reinterpret_cast<FlutterServiceApp *>(data);
    service_app->OnAppControlReceived(a);
  };

  app_event_handler_h handler;
  service_app_add_event_handler(
      &handler, APP_EVENT_LOW_MEMORY,
      [](app_event_info_h e, void *data) {
        auto *service_app = reinterpret_cast<FlutterServiceApp *>(data);
        service_app->OnLowMemory(e);
      },
      this);
  service_app_add_event_handler(
      &handler, APP_EVENT_LOW_BATTERY,
      [](app_event_info_h e, void *data) {
        auto *service_app = reinterpret_cast<FlutterServiceApp *>(data);
        service_app->OnLowBattery(e);
      },
      this);
  service_app_add_event_handler(
      &handler, APP_EVENT_LANGUAGE_CHANGED,
      [](app_event_info_h e, void *data) {
        auto *service_app = reinterpret_cast<FlutterServiceApp *>(data);
        service_app->OnLanguageChanged(e);
      },
      this);
  service_app_add_event_handler(
      &handler, APP_EVENT_REGION_FORMAT_CHANGED,
      [](app_event_info_h e, void *data) {
        auto *service_app = reinterpret_cast<FlutterServiceApp *>(data);
        service_app->OnRegionFormatChanged(e);
      },
      this);

  int ret = service_app_main(argc, argv, &lifecycle_cb, this);
  if (ret != APP_ERROR_NONE) {
    TizenLog::Error("Could not launch a service application. (%d)", ret);
  }
  return ret;
}

FlutterDesktopPluginRegistrarRef FlutterServiceApp::GetRegistrarForPlugin(
    const std::string &plugin_name) {
  if (engine_) {
    return FlutterDesktopEngineGetPluginRegistrar(engine_, plugin_name.c_str());
  }
  return nullptr;
}
