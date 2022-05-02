// Copyright 2021 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "include/flutter_app.h"

#include <cassert>
#include <cerrno>
#include <fstream>

#include "tizen_log.h"
#include "utils.h"

bool FlutterApp::OnCreate() {
  TizenLog::Debug("Launching a Flutter application...");

  FlutterDesktopWindowProperties window_prop = {};
  window_prop.x = window_offset_x_;
  window_prop.y = window_offset_y_;
  window_prop.width = window_width_;
  window_prop.height = window_height_;
  window_prop.transparent = is_window_transparent_;
  window_prop.focusable = is_window_focusable_;
  window_prop.top_level = is_top_level_;

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
  view_ = FlutterDesktopViewCreateFromNewWindow(window_prop, engine_);
  if (!view_) {
    TizenLog::Error("Could not launch a Flutter application.");
    return false;
  }
  return true;
}

void FlutterApp::OnResume() {
  assert(IsRunning());

  FlutterDesktopEngineNotifyAppIsResumed(engine_);
}

void FlutterApp::OnPause() {
  assert(IsRunning());

  FlutterDesktopEngineNotifyAppIsPaused(engine_);
}

void FlutterApp::OnTerminate() {
  assert(IsRunning());

  TizenLog::Debug("Shutting down the application...");

  FlutterDesktopEngineShutdown(engine_);
  engine_ = nullptr;
}

void FlutterApp::OnAppControlReceived(app_control_h app_control) {
  assert(IsRunning());

  FlutterDesktopEngineNotifyAppControl(engine_, app_control);
}

void FlutterApp::OnLowMemory(app_event_info_h event_info) {
  assert(IsRunning());

  FlutterDesktopEngineNotifyLowMemoryWarning(engine_);
}

void FlutterApp::OnLanguageChanged(app_event_info_h event_info) {
  assert(IsRunning());

  FlutterDesktopEngineNotifyLocaleChange(engine_);
}

void FlutterApp::OnRegionFormatChanged(app_event_info_h event_info) {
  assert(IsRunning());

  FlutterDesktopEngineNotifyLocaleChange(engine_);
}

int FlutterApp::Run(int argc, char **argv) {
  ui_app_lifecycle_callback_s lifecycle_cb = {};
  lifecycle_cb.create = [](void *data) -> bool {
    auto *app = reinterpret_cast<FlutterApp *>(data);
    return app->OnCreate();
  };
  lifecycle_cb.resume = [](void *data) {
    auto *app = reinterpret_cast<FlutterApp *>(data);
    app->OnResume();
  };
  lifecycle_cb.pause = [](void *data) {
    auto *app = reinterpret_cast<FlutterApp *>(data);
    app->OnPause();
  };
  lifecycle_cb.terminate = [](void *data) {
    auto *app = reinterpret_cast<FlutterApp *>(data);
    app->OnTerminate();
  };
  lifecycle_cb.app_control = [](app_control_h a, void *data) {
    auto *app = reinterpret_cast<FlutterApp *>(data);
    app->OnAppControlReceived(a);
  };

  app_event_handler_h handler;
  ui_app_add_event_handler(
      &handler, APP_EVENT_LOW_MEMORY,
      [](app_event_info_h e, void *data) {
        auto *app = reinterpret_cast<FlutterApp *>(data);
        app->OnLowMemory(e);
      },
      this);
  ui_app_add_event_handler(
      &handler, APP_EVENT_LOW_BATTERY,
      [](app_event_info_h e, void *data) {
        auto *app = reinterpret_cast<FlutterApp *>(data);
        app->OnLowBattery(e);
      },
      this);
  ui_app_add_event_handler(
      &handler, APP_EVENT_LANGUAGE_CHANGED,
      [](app_event_info_h e, void *data) {
        auto *app = reinterpret_cast<FlutterApp *>(data);
        app->OnLanguageChanged(e);
      },
      this);
  ui_app_add_event_handler(
      &handler, APP_EVENT_REGION_FORMAT_CHANGED,
      [](app_event_info_h e, void *data) {
        auto *app = reinterpret_cast<FlutterApp *>(data);
        app->OnRegionFormatChanged(e);
      },
      this);
  ui_app_add_event_handler(
      &handler, APP_EVENT_DEVICE_ORIENTATION_CHANGED,
      [](app_event_info_h e, void *data) {
        auto *app = reinterpret_cast<FlutterApp *>(data);
        app->OnDeviceOrientationChanged(e);
      },
      this);

  int ret = ui_app_main(argc, argv, &lifecycle_cb, this);
  if (ret != APP_ERROR_NONE) {
    TizenLog::Error("Could not launch an application. (%d)", ret);
  }
  return ret;
}

FlutterDesktopPluginRegistrarRef FlutterApp::GetRegistrarForPlugin(
    const std::string &plugin_name) {
  if (engine_) {
    return FlutterDesktopEngineGetPluginRegistrar(engine_, plugin_name.c_str());
  }
  return nullptr;
}
