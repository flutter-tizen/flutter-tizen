// Copyright 2022 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "include/flutter_engine.h"

#include "utils.h"

std::unique_ptr<FlutterEngine> FlutterEngine::Create(
    const std::string& assets_path, const std::string& icu_data_path,
    const std::string& aot_library_path, const std::string& dart_entrypoint,
    const std::vector<std::string>& dart_entrypoint_args) {
  return std::unique_ptr<FlutterEngine>(
      new FlutterEngine(assets_path, icu_data_path, aot_library_path,
                        dart_entrypoint, dart_entrypoint_args));
}

FlutterEngine::FlutterEngine(
    const std::string& assets_path, const std::string& icu_data_path,
    const std::string& aot_library_path, const std::string& dart_entrypoint,
    const std::vector<std::string>& dart_entrypoint_args) {
  FlutterDesktopEngineProperties engine_prop = {};
  engine_prop.assets_path = assets_path.c_str();
  engine_prop.icu_data_path = icu_data_path.c_str();
  engine_prop.aot_library_path = aot_library_path.c_str();

  // Read engine arguments passed from the tool.
  Utils::ParseEngineArgs(&engine_arguments_);
  std::vector<const char*> switches;
  for (auto& arg : engine_arguments_) {
    switches.push_back(arg.c_str());
  }
  engine_prop.switches = switches.data();
  engine_prop.switches_count = switches.size();

  engine_prop.entrypoint = dart_entrypoint.c_str();

  std::vector<const char*> entrypoint_args;
  for (auto& arg : dart_entrypoint_args) {
    entrypoint_args.push_back(arg.c_str());
  }
  engine_prop.dart_entrypoint_argc = entrypoint_args.size();
  engine_prop.dart_entrypoint_argv = entrypoint_args.data();

  engine_ = FlutterDesktopEngineCreate(engine_prop);
}

FlutterEngine::~FlutterEngine() {
  if (owns_engine_) {
    Shutdown();
  }
}

bool FlutterEngine::Run() {
  if (engine_) {
    is_running_ = FlutterDesktopEngineRun(engine_);
  }
  return is_running_;
}

void FlutterEngine::Shutdown() {
  if (engine_) {
    FlutterDesktopEngineShutdown(engine_);
  }
}

void FlutterEngine::NotifyAppIsResumed() {
  if (engine_) {
    FlutterDesktopEngineNotifyAppIsResumed(engine_);
  }
}

void FlutterEngine::NotifyAppIsInactive() {
  if (engine_) {
    FlutterDesktopEngineNotifyAppIsInactive(engine_);
  }
}

void FlutterEngine::NotifyAppIsPaused() {
  if (engine_) {
    FlutterDesktopEngineNotifyAppIsPaused(engine_);
  }
}

void FlutterEngine::NotifyAppIsDetached() {
  if (engine_) {
    FlutterDesktopEngineNotifyAppIsDetached(engine_);
  }
}

void FlutterEngine::NotifyAppControl(app_control_h app_control) {
  FlutterDesktopEngineNotifyAppControl(engine_, app_control);
}

void FlutterEngine::NotifyLowMemoryWarning() {
  FlutterDesktopEngineNotifyLowMemoryWarning(engine_);
}

void FlutterEngine::NotifyLocaleChange() {
  FlutterDesktopEngineNotifyLocaleChange(engine_);
}

FlutterDesktopEngineRef FlutterEngine::RelinquishEngine() {
  owns_engine_ = false;
  return engine_;
}

FlutterDesktopPluginRegistrarRef FlutterEngine::GetRegistrarForPlugin(
    const std::string& plugin_name) {
  if (engine_) {
    return FlutterDesktopEngineGetPluginRegistrar(engine_, plugin_name.c_str());
  }
  return nullptr;
}
