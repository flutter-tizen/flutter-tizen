// Copyright 2026 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// The prebuilt runner of apps created with --tizen-language=native.
//
// A single binary serves every application in the package: the app type
// (UI or service), Dart entrypoint, and optional window configuration are read
// from tizen-manifest.xml at runtime, and native plugins are loaded from
// libflutter_plugins.so.

#include <app_common.h>
#include <app_manager.h>
#include <dlfcn.h>
#include <unistd.h>

#include <cerrno>
#include <cmath>
#include <cstdlib>
#include <limits>
#include <map>
#include <string>

#include "../include/flutter.h"
#include "../tizen_log.h"

namespace {

constexpr char kMetadataKeyDartEntrypoint[] =
    "http://tizen.org/metadata/flutter_tizen/dart_entrypoint";
constexpr char kMetadataPrefix[] = "http://tizen.org/metadata/flutter_tizen/";

// Exported by libflutter_plugins.so. See NativePlugins in plugins.dart.
constexpr char kRegisterPluginsSymbol[] = "FlutterRegisterPlugins";

using RegisterPluginsFunc = void (*)(flutter::PluginRegistry *);

bool RegisterPlugins(flutter::PluginRegistry *registry) {
  char *res_path = app_get_resource_path();
  if (!res_path) {
    TizenLog::Error("Could not get the resource path.");
    return false;
  }
  std::string lib_path = std::string(res_path) + "../lib/libflutter_plugins.so";
  free(res_path);

  if (access(lib_path.c_str(), F_OK) != 0) {
    // The app has no native plugins.
    return true;
  }
  // Same as C++ apps, which load the library as a dependency of the runner.
  void *handle = dlopen(lib_path.c_str(), RTLD_LAZY | RTLD_GLOBAL);
  if (!handle) {
    TizenLog::Error("Could not load %s: %s", lib_path.c_str(), dlerror());
    return false;
  }
  auto register_plugins = reinterpret_cast<RegisterPluginsFunc>(
      dlsym(handle, kRegisterPluginsSymbol));
  if (!register_plugins) {
    TizenLog::Error("Could not find %s: %s", kRegisterPluginsSymbol, dlerror());
    return false;
  }
  register_plugins(registry);
  return true;
}

template <typename T>
class App : public T {
 public:
  bool OnCreate() override {
    return T::OnCreate() && T::IsRunning() && RegisterPlugins(this);
  }
};

struct AppConfig {
  bool is_service = false;
  std::string dart_entrypoint;
  std::map<std::string, std::string> configuration;
};

bool ParseConfigurationValue(const std::string &value, int32_t *result) {
  char *end = nullptr;
  errno = 0;
  const long long parsed = strtoll(value.c_str(), &end, 10);
  if (value.empty() || *end != '\0' || errno == ERANGE ||
      parsed < std::numeric_limits<int32_t>::min() ||
      parsed > std::numeric_limits<int32_t>::max()) {
    return false;
  }
  *result = static_cast<int32_t>(parsed);
  return true;
}

bool ParseConfigurationValue(const std::string &value, double *result) {
  char *end = nullptr;
  const double parsed = strtod(value.c_str(), &end);
  if (value.empty() || *end != '\0' || !std::isfinite(parsed)) {
    return false;
  }
  *result = parsed;
  return true;
}

bool ParseConfigurationValue(const std::string &value, bool *result) {
  if (value != "true" && value != "false") {
    return false;
  }
  *result = value == "true";
  return true;
}

template <typename T>
void ApplyConfiguration(const AppConfig &config, const char *key, T *target,
                        T minimum = std::numeric_limits<T>::lowest()) {
  const auto entry = config.configuration.find(key);
  if (entry == config.configuration.end()) {
    return;
  }
  T value;
  if (!ParseConfigurationValue(entry->second, &value) || value < minimum) {
    TizenLog::Error("Ignoring invalid window configuration: %s=%s", key,
                    entry->second.c_str());
    return;
  }
  *target = value;
}

class UiApp : public App<FlutterApp> {
 public:
  explicit UiApp(const AppConfig &config) {
    // Apply only explicit overrides before FlutterApp::OnCreate creates a view.
    ApplyConfiguration(config, "window_offset_x", &window_offset_x_);
    ApplyConfiguration(config, "window_offset_y", &window_offset_y_);
    ApplyConfiguration(config, "window_width", &window_width_, int32_t{0});
    ApplyConfiguration(config, "window_height", &window_height_, int32_t{0});
    ApplyConfiguration(config, "transparent", &is_window_transparent_);
    ApplyConfiguration(config, "focusable", &is_window_focusable_);
    ApplyConfiguration(config, "top_level", &is_top_level_);
    ApplyConfiguration(config, "user_pixel_ratio", &user_pixel_ratio_, 0.0);
    ApplyConfiguration(config, "pointing_device_support",
                       &is_pointing_device_support);
    ApplyConfiguration(config, "floating_menu_support",
                       &is_floating_menu_support);
  }
};

AppConfig GetAppConfig() {
  AppConfig config;
  char *app_id = nullptr;
  if (app_get_id(&app_id) != APP_ERROR_NONE) {
    TizenLog::Error("Could not get the app ID.");
    return config;
  }
  app_info_h app_info = nullptr;
  int ret = app_manager_get_app_info(app_id, &app_info);
  free(app_id);
  if (ret != APP_MANAGER_ERROR_NONE) {
    TizenLog::Error("Could not get the app info. (%d)", ret);
    return config;
  }

  app_info_app_component_type_e component_type;
  if (app_info_get_app_component_type(app_info, &component_type) ==
      APP_MANAGER_ERROR_NONE) {
    config.is_service =
        component_type == APP_INFO_APP_COMPONENT_TYPE_SERVICE_APP;
  }
  app_info_foreach_metadata(
      app_info,
      [](const char *key, const char *value, void *user_data) -> bool {
        if (!key || !value) {
          return true;
        }
        auto *config = static_cast<AppConfig *>(user_data);
        const std::string metadata_key(key);
        if (metadata_key == kMetadataKeyDartEntrypoint) {
          config->dart_entrypoint = value;
        } else if (metadata_key.compare(0, sizeof(kMetadataPrefix) - 1,
                                        kMetadataPrefix) == 0) {
          config->configuration[metadata_key.substr(sizeof(kMetadataPrefix) -
                                                    1)] = value;
        }
        return true;
      },
      &config);
  app_info_destroy(app_info);
  return config;
}

}  // namespace

int main(int argc, char *argv[]) {
  AppConfig config = GetAppConfig();
  if (config.is_service) {
    App<FlutterServiceApp> app;
    app.SetDartEntrypoint(config.dart_entrypoint);
    return app.Run(argc, argv);
  }
  UiApp app(config);
  app.SetDartEntrypoint(config.dart_entrypoint);
  return app.Run(argc, argv);
}
