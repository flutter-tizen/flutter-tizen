// Copyright 2021 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "include/flutter_service_app.h"

#include <cassert>

#include "tizen_log.h"

bool FlutterServiceApp::OnCreate() {
  TizenLog::Debug("Launching a Flutter service application...");

  engine_ = FlutterEngine::Create(dart_entrypoint_, dart_entrypoint_args_);
  if (!engine_) {
    TizenLog::Error("Could not create a Flutter engine.");
    return false;
  }

  if (!engine_->Run()) {
    TizenLog::Error("Could not run a Flutter engine.");
    return false;
  }
  return true;
}

void FlutterServiceApp::OnTerminate() {
  assert(IsRunning());
  TizenLog::Debug("Shutting down the service application...");
  engine_ = nullptr;
}

void FlutterServiceApp::OnAppControlReceived(app_control_h app_control) {
  assert(IsRunning());
  engine_->NotifyAppControl(app_control);
}

void FlutterServiceApp::OnLowMemory(app_event_info_h event_info) {
  assert(IsRunning());
  engine_->NotifyLowMemoryWarning();
}

void FlutterServiceApp::OnLanguageChanged(app_event_info_h event_info) {
  assert(IsRunning());
  engine_->NotifyLocaleChange();
}

void FlutterServiceApp::OnRegionFormatChanged(app_event_info_h event_info) {
  assert(IsRunning());
  engine_->NotifyLocaleChange();
}

int FlutterServiceApp::Run(int argc, char **argv) {
  for (int i = 0; i < argc; i++) {
    dart_entrypoint_args_.push_back(argv[i]);
  }

  service_app_lifecycle_callback_s lifecycle_cb = {};
  lifecycle_cb.create = [](void *data) -> bool {
    auto *app = reinterpret_cast<FlutterServiceApp *>(data);
    return app->OnCreate();
  };
  lifecycle_cb.terminate = [](void *data) {
    auto *app = reinterpret_cast<FlutterServiceApp *>(data);
    app->OnTerminate();
  };
  lifecycle_cb.app_control = [](app_control_h a, void *data) {
    auto *app = reinterpret_cast<FlutterServiceApp *>(data);
    app->OnAppControlReceived(a);
  };

  app_event_handler_h handler;
  service_app_add_event_handler(
      &handler, APP_EVENT_LOW_MEMORY,
      [](app_event_info_h e, void *data) {
        auto *app = reinterpret_cast<FlutterServiceApp *>(data);
        app->OnLowMemory(e);
      },
      this);
  service_app_add_event_handler(
      &handler, APP_EVENT_LOW_BATTERY,
      [](app_event_info_h e, void *data) {
        auto *app = reinterpret_cast<FlutterServiceApp *>(data);
        app->OnLowBattery(e);
      },
      this);
  service_app_add_event_handler(
      &handler, APP_EVENT_LANGUAGE_CHANGED,
      [](app_event_info_h e, void *data) {
        auto *app = reinterpret_cast<FlutterServiceApp *>(data);
        app->OnLanguageChanged(e);
      },
      this);
  service_app_add_event_handler(
      &handler, APP_EVENT_REGION_FORMAT_CHANGED,
      [](app_event_info_h e, void *data) {
        auto *app = reinterpret_cast<FlutterServiceApp *>(data);
        app->OnRegionFormatChanged(e);
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
    return engine_->GetRegistrarForPlugin(plugin_name);
  }
  return nullptr;
}
