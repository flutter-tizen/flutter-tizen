// Copyright 2021 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "include/flutter_service_app.h"

#include "tizen_log.h"

FlutterServiceApp::FlutterServiceApp() {
  is_headed_ = false;
}

int FlutterServiceApp::Run(int argc, char **argv) {
  service_app_lifecycle_callback_s lifecycle_cb = {};
  lifecycle_cb.create = [](void *data) -> bool {
    FlutterApp *app = (FlutterApp *)data;
    return app->OnCreate();
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
  service_app_add_event_handler(
      &handler, APP_EVENT_LOW_MEMORY,
      [](app_event_info_h e, void *data) {
        FlutterApp *app = (FlutterApp *)data;
        app->OnLowMemory(e);
      },
      this);
  service_app_add_event_handler(
      &handler, APP_EVENT_LOW_BATTERY,
      [](app_event_info_h e, void *data) {
        FlutterApp *app = (FlutterApp *)data;
        app->OnLowBattery(e);
      },
      this);
  service_app_add_event_handler(
      &handler, APP_EVENT_LANGUAGE_CHANGED,
      [](app_event_info_h e, void *data) {
        FlutterApp *app = (FlutterApp *)data;
        app->OnLanguageChanged(e);
      },
      this);
  service_app_add_event_handler(
      &handler, APP_EVENT_REGION_FORMAT_CHANGED,
      [](app_event_info_h e, void *data) {
        FlutterApp *app = (FlutterApp *)data;
        app->OnRegionFormatChanged(e);
      },
      this);

  int ret = service_app_main(argc, argv, &lifecycle_cb, this);
  if (ret != APP_ERROR_NONE) {
    TizenLog::Error("Could not launch a service application. (%d)", ret);
  }
  return ret;
}
