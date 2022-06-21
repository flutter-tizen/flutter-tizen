// Copyright 2022 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef FLUTTER_TIZEN_EMBEDDING_CPP_INCLUDE_FLUTTER_ENGINE_H_
#define FLUTTER_TIZEN_EMBEDDING_CPP_INCLUDE_FLUTTER_ENGINE_H_

#include <flutter/plugin_registry.h>
#include <flutter_tizen.h>

#include <string>
#include <vector>

class FlutterEngine : public flutter::PluginRegistry {
 public:
  FlutterEngine(const std::string& assets_path,
                const std::string& icu_data_path,
                const std::string& aot_library_path,
                const std::vector<std::string>& engine_arguments,
                const std::string& dart_entrypoint,
                const std::vector<std::string>& dart_entrypoint_arguments);
  virtual ~FlutterEngine();

  // Prevent copying.
  FlutterEngine(FlutterEngine const&) = delete;
  FlutterEngine& operator=(FlutterEngine const&) = delete;

  bool Run();

  FlutterDesktopPluginRegistrarRef GetRegistrarForPlugin(
      const std::string& plugin_name) override;

 private:
  std::string assets_path_;
  std::string icu_data_path_;
  std::string aot_library_path_;
  std::vector<std::string> engine_arguments_;
  std::string dart_entrypoint_;
  std::vector<std::string> dart_entrypoint_arguments_;

  // The Flutter engine instance handle.
  FlutterDesktopEngineRef engine_ = nullptr;
};

#endif /* FLUTTER_TIZEN_EMBEDDING_CPP_INCLUDE_FLUTTER_ENGINE_H_ */
