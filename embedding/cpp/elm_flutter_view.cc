// Copyright 2021 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "include/elm_flutter_view.h"

#include "tizen_log.h"
#include "utils.h"

bool ElmFlutterView::OnCreate() {
  TizenLog::Debug("Launching a Flutter application...");

  FlutterDesktopViewProperties view_prop = {};
  view_prop.width = window_width_;
  view_prop.height = window_height_;
  view_prop.elm_parent = elm_parent_;

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

  view_ = FlutterDesktopViewCreateFromNewView(view_prop, engine_, elm_parent_);
  if (!view_) {
    TizenLog::Error("Could not launch a Flutter application.");
    return false;
  }

  evas_image_ = FlutterDesktopViewGetEvasImageHandle(engine_);
  if (!evas_image_) {
    TizenLog::Error("Could not get a image handle.");
    return false;
  }

  return true;
}

FlutterDesktopPluginRegistrarRef ElmFlutterView::GetRegistrarForPlugin(
    const std::string &plugin_name) {
  if (engine_) {
    return FlutterDesktopEngineGetPluginRegistrar(engine_, plugin_name.c_str());
  }
  return nullptr;
}
