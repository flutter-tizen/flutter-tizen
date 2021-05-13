// Copyright 2021 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "include/flutter_app.h"

#include <system_info.h>

#include <cassert>
#include <cerrno>
#include <fstream>

#include "tizen_log.h"

bool FlutterApp::OnCreate() {
  TizenLog::Debug("Launching a Flutter application...");

  std::string res_path;
  {
    auto path = app_get_resource_path();
    if (path == nullptr) {
      TizenLog::Error("Could not obtain the app directory info.");
      return false;
    }
    res_path = path;
    free(path);
  }
  std::string assets_path(res_path + "/flutter_assets");
  std::string icu_data_path(res_path + "/icudtl.dat");
  std::string aot_lib_path(res_path + "/../lib/libapp.so");

  // Read engine arguments passed from the tool.
  ParseEngineArgs();

  std::vector<const char *> switches;
  for (auto &arg : engine_args) {
    switches.push_back(arg.c_str());
  }

  FlutterDesktopEngineProperties engine_prop = {};
  engine_prop.assets_path = assets_path.c_str();
  engine_prop.icu_data_path = icu_data_path.c_str();
  engine_prop.aot_library_path = aot_lib_path.c_str();
  engine_prop.switches = switches.data();
  engine_prop.switches_count = switches.size();

  handle = FlutterDesktopRunEngine(engine_prop, true);
  if (!handle) {
    TizenLog::Error("Could not launch a Flutter application.");
    return false;
  }

  return true;
}

void FlutterApp::OnResume() {
  assert(IsRunning());

  FlutterDesktopNotifyAppIsResumed(handle);
}

void FlutterApp::OnPause() {
  assert(IsRunning());

  FlutterDesktopNotifyAppIsPaused(handle);
}

void FlutterApp::OnTerminate() {
  assert(IsRunning());

  TizenLog::Debug("Shutting down the application...");

  FlutterDesktopShutdownEngine(handle);
  handle = nullptr;
}

void FlutterApp::OnLowMemory(app_event_info_h event_info) {
  assert(IsRunning());

  FlutterDesktopNotifyLowMemoryWarning(handle);
}

void FlutterApp::OnLanguageChanged(app_event_info_h event_info) {
  assert(IsRunning());

  FlutterDesktopNotifyLocaleChange(handle);
}

void FlutterApp::OnRegionFormatChanged(app_event_info_h event_info) {
  assert(IsRunning());

  FlutterDesktopNotifyLocaleChange(handle);
}

int FlutterApp::Run(int argc, char **argv) {
  ui_app_lifecycle_callback_s lifecycle_cb = {};
  lifecycle_cb.create = [](void *data) -> bool {
    FlutterApp *app = (FlutterApp *)data;
    return app->OnCreate();
  };
  lifecycle_cb.resume = [](void *data) {
    FlutterApp *app = (FlutterApp *)data;
    app->OnResume();
  };
  lifecycle_cb.pause = [](void *data) {
    FlutterApp *app = (FlutterApp *)data;
    app->OnPause();
  };
  lifecycle_cb.terminate = [](void *data) {
    FlutterApp *app = (FlutterApp *)data;
    app->OnTerminate();
  };
  lifecycle_cb.app_control = [](app_control_h a, void *data) {
    FlutterApp *app = (FlutterApp *)data;
    app->OnAppControlReceived(a);
  };

  app_event_handler_h handler;
  ui_app_add_event_handler(
      &handler, APP_EVENT_LOW_MEMORY,
      [](app_event_info_h e, void *data) {
        FlutterApp *app = (FlutterApp *)data;
        app->OnLowMemory(e);
      },
      this);
  ui_app_add_event_handler(
      &handler, APP_EVENT_LOW_BATTERY,
      [](app_event_info_h e, void *data) {
        FlutterApp *app = (FlutterApp *)data;
        app->OnLowBattery(e);
      },
      this);
  ui_app_add_event_handler(
      &handler, APP_EVENT_LANGUAGE_CHANGED,
      [](app_event_info_h e, void *data) {
        FlutterApp *app = (FlutterApp *)data;
        app->OnLanguageChanged(e);
      },
      this);
  ui_app_add_event_handler(
      &handler, APP_EVENT_REGION_FORMAT_CHANGED,
      [](app_event_info_h e, void *data) {
        FlutterApp *app = (FlutterApp *)data;
        app->OnRegionFormatChanged(e);
      },
      this);
  ui_app_add_event_handler(
      &handler, APP_EVENT_DEVICE_ORIENTATION_CHANGED,
      [](app_event_info_h e, void *data) {
        FlutterApp *app = (FlutterApp *)data;
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
  if (handle) {
    return FlutterDesktopGetPluginRegistrar(handle, plugin_name.c_str());
  }
  return nullptr;
}

void FlutterApp::ParseEngineArgs() {
  char *app_id;
  if (app_get_id(&app_id) != 0) {
    TizenLog::Warn("App id is not found.");
    return;
  }
  std::string temp_path("/home/owner/share/tmp/sdk_tools/" +
                        std::string(app_id) + ".rpm");
  free(app_id);

  std::ifstream file(temp_path);
  if (!file.is_open()) {
    return;
  }
  std::string line;
  while (file && !file.eof() && std::getline(file, line)) {
    TizenLog::Info("Enabled: %s", line.c_str());
    engine_args.push_back(line.c_str());
  }
  file.close();

  if (remove(temp_path.c_str()) != 0) {
    TizenLog::Warn("Error removing file: %s", strerror(errno));
  }
}
