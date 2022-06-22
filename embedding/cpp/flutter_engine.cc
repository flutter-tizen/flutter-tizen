// Copyright 2022 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "include/flutter_engine.h"

#include "utils.h"

std::unique_ptr<FlutterEngine> FlutterEngine::Create(
    const std::string& assets_path, const std::string& icu_data_path,
    const std::string& aot_library_path, const std::string& dart_entrypoint,
    const std::vector<std::string>& dart_entrypoint_arguments) {
  return std::unique_ptr<FlutterEngine>(
      new FlutterEngine(assets_path, icu_data_path, aot_library_path,
                        dart_entrypoint, dart_entrypoint_arguments));
}

FlutterEngine::FlutterEngine(
    const std::string& assets_path, const std::string& icu_data_path,
    const std::string& aot_library_path, const std::string& dart_entrypoint,
    const std::vector<std::string>& dart_entrypoint_arguments)
    : assets_path_(assets_path),
      icu_data_path_(icu_data_path),
      aot_library_path_(aot_library_path),
      dart_entrypoint_(dart_entrypoint),
      dart_entrypoint_arguments_(dart_entrypoint_arguments) {
  FlutterDesktopEngineProperties engine_prop = {};
  engine_prop.assets_path = assets_path_.c_str();
  engine_prop.icu_data_path = icu_data_path_.c_str();
  engine_prop.aot_library_path = aot_library_path_.c_str();

  // Read engine arguments passed from the tool.
  Utils::ParseEngineArgs(&engine_arguments_);
  std::vector<const char*> switches;
  for (auto& arg : engine_arguments_) {
    switches.push_back(arg.c_str());
  }
  engine_prop.switches = switches.data();
  engine_prop.switches_count = switches.size();

  engine_prop.entrypoint = dart_entrypoint_.c_str();

  std::vector<const char*> entrypoint_args;
  for (auto& arg : dart_entrypoint_arguments_) {
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

void FlutterEngine::Resume() {
  if (engine_) {
    FlutterDesktopEngineNotifyAppIsResumed(engine_);
  }
}

void FlutterEngine::Pause() {
  if (engine_) {
    FlutterDesktopEngineNotifyAppIsInactive(engine_);
  }
}

void FlutterEngine::Stop() {
  if (engine_) {
    FlutterDesktopEngineNotifyAppIsPaused(engine_);
  }
}

void FlutterEngine::NotifyAppControl(void* app_control) {
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
