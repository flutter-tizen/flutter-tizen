// Copyright 2022 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "include/flutter_engine.h"

#include <app.h>
#include <app_info.h>
#include <app_manager.h>

#include <cerrno>

#include "tizen_log.h"

namespace {

static inline const char* kMetadataKeyEnableImepeller =
    "http://tizen.org/metadata/flutter_tizen/enable_impeller";

// Reads metadata from tizen-manifest.xml
std::map<std::string, std::string> GetMetadata(std::string app_id) {
  std::map<std::string, std::string> map;
  app_info_h app_info;
  int ret = app_manager_get_app_info(app_id.c_str(), &app_info);
  if (ret != APP_MANAGER_ERROR_NONE) {
    TizenLog::Error("Failed to retrieve app info.");
    return map;
  }

  ret = app_info_foreach_metadata(
      app_info,
      [](const char* key, const char* value, void* user_data) -> bool {
        auto* map = static_cast<std::map<std::string, std::string>*>(user_data);
        map->insert(std::pair<std::string, std::string>(key, value));
        return true;
      },
      &map);
  if (ret != APP_MANAGER_ERROR_NONE) {
    TizenLog::Error("Failed to get app metadata.");
  }
  return map;
}

// Reads engine arguments passed from the flutter-tizen tool.
std::vector<std::string> ParseEngineArgs() {
  std::vector<std::string> engine_args;
  char* id;
  if (app_get_id(&id) != 0) {
    TizenLog::Warn("The app ID is not found.");
    return engine_args;
  }

  std::string app_id = std::string(id);
  std::string temp_path("/home/owner/share/tmp/sdk_tools/" + app_id + ".rpm");
  free(id);

  auto file = fopen(temp_path.c_str(), "r");
  if (file) {
    char* line = nullptr;
    size_t len = 0;

    while (getline(&line, &len, file) > 0) {
      if (line[strlen(line) - 1] == '\n') {
        line[strlen(line) - 1] = 0;
      }
      engine_args.push_back(line);
    }
    free(line);
    fclose(file);

    if (remove(temp_path.c_str()) != 0) {
      TizenLog::Warn("Error removing file: %s", strerror(errno));
    }
  }

  std::map<std::string, std::string> metadata = GetMetadata(app_id);
  auto it = metadata.find(kMetadataKeyEnableImepeller);
  if (it != metadata.end()) {
    auto engine_args_it =
        std::find(engine_args.begin(), engine_args.end(), "--enable-impeller");
    if (engine_args_it == engine_args.end() && it->second == "true") {
      engine_args.insert(engine_args.begin(), "--enable-impeller");
    } else if (engine_args_it != engine_args.end() && it->second == "false") {
      engine_args.erase(engine_args_it);
    }
  }

  for (const std::string& arg : engine_args) {
    TizenLog::Info("Enabled: %s", arg.c_str());
  }

  return engine_args;
}

}  // namespace

std::unique_ptr<FlutterEngine> FlutterEngine::Create(
    const std::string& dart_entrypoint,
    const std::vector<std::string>& dart_entrypoint_args) {
  return FlutterEngine::Create("../res/flutter_assets", "../res/icudtl.dat",
                               "../lib/libapp.so", dart_entrypoint,
                               dart_entrypoint_args);
}

std::unique_ptr<FlutterEngine> FlutterEngine::Create(
    const std::string& assets_path, const std::string& icu_data_path,
    const std::string& aot_library_path, const std::string& dart_entrypoint,
    const std::vector<std::string>& dart_entrypoint_args) {
  FlutterEngine* engine =
      new FlutterEngine(assets_path, icu_data_path, aot_library_path,
                        dart_entrypoint, dart_entrypoint_args);
  if (engine->engine_) {
    return std::unique_ptr<FlutterEngine>(engine);
  } else {
    delete engine;
    return nullptr;
  }
}

FlutterEngine::FlutterEngine(
    const std::string& assets_path, const std::string& icu_data_path,
    const std::string& aot_library_path, const std::string& dart_entrypoint,
    const std::vector<std::string>& dart_entrypoint_args) {
  FlutterDesktopEngineProperties engine_prop = {};
  engine_prop.assets_path = assets_path.c_str();
  engine_prop.icu_data_path = icu_data_path.c_str();
  engine_prop.aot_library_path = aot_library_path.c_str();

  std::vector<std::string> engine_args = ParseEngineArgs();
  std::vector<const char*> switches;
  for (const std::string& arg : engine_args) {
    switches.push_back(arg.c_str());
  }
  engine_prop.switches = switches.data();
  engine_prop.switches_count = switches.size();

  engine_prop.entrypoint =
      dart_entrypoint.empty() ? nullptr : dart_entrypoint.c_str();

  std::vector<const char*> entrypoint_args;
  for (const std::string& arg : dart_entrypoint_args) {
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
    return FlutterDesktopEngineRun(engine_);
  }
  return false;
}

void FlutterEngine::Shutdown() {
  if (engine_) {
    FlutterDesktopEngineShutdown(engine_);
    engine_ = nullptr;
  }
}

void FlutterEngine::NotifyAppIsResumed() {
  if (engine_) {
    FlutterDesktopEngineNotifyAppIsResumed(engine_);
  }
}

void FlutterEngine::NotifyAppIsPaused() {
  if (engine_) {
    FlutterDesktopEngineNotifyAppIsPaused(engine_);
  }
}

void FlutterEngine::NotifyAppControl(app_control_h app_control) {
  if (engine_) {
    FlutterDesktopEngineNotifyAppControl(engine_, app_control);
  }
}

void FlutterEngine::NotifyLowMemoryWarning() {
  if (engine_) {
    FlutterDesktopEngineNotifyLowMemoryWarning(engine_);
  }
}

void FlutterEngine::NotifyLocaleChange() {
  if (engine_) {
    FlutterDesktopEngineNotifyLocaleChange(engine_);
  }
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
