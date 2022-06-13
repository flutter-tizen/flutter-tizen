// Copyright 2021 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef FLUTTER_TIZEN_EMBEDDING_CPP_INCLUDE_ELM_FLUTTER_VIEW_H_
#define FLUTTER_TIZEN_EMBEDDING_CPP_INCLUDE_ELM_FLUTTER_VIEW_H_

#include <Elementary.h>
#include <flutter/plugin_registry.h>
#include <flutter_tizen.h>

#include <string>
#include <vector>

// The app base class which creates and manages the Flutter engine instance.
class ElmFlutterView : public flutter::PluginRegistry {
 public:
 explicit ElmFlutterView() {}
  explicit ElmFlutterView(Evas_Object *parent, int32_t width, int32_t height)
      : parent_(parent), width_(width), height_(height) {}
  virtual ~ElmFlutterView() {}

  FlutterDesktopPluginRegistrarRef GetRegistrarForPlugin(
      const std::string &plugin_name) override;

  bool IsRunning() { return engine_ != nullptr; }

  Evas_Object *evas_object() { return evas_object_; };

  void Resize(int32_t width, int32_t height);

  bool RunEngine();

 private:
  // The switches to pass to the Flutter engine.
  // Custom switches may be added before `OnCreate` is called.
  std::vector<std::string> engine_args_;

  // The optional entrypoint in the Dart project. If the value is empty,
  // defaults to main().
  std::string dart_entrypoint_;

  // The list of Dart entrypoint arguments.
  std::vector<std::string> dart_entrypoint_args_;

  // The Flutter engine instance handle.
  FlutterDesktopEngineRef engine_ = nullptr;

  // The Flutter view instance handle.
  FlutterDesktopViewRef view_ = nullptr;

  // The Evas object.
  Evas_Object *evas_object_ = nullptr;

  // The Evas object's parent instance handle.
  Evas_Object *parent_ = nullptr;

  // The width of the view, or the maximum width if the value is zero.
  int32_t width_ = 0;

  // The height of the view, or the maximum height if the value is zero.
  int32_t height_ = 0;
};

#endif /* FLUTTER_TIZEN_EMBEDDING_CPP_INCLUDE_ELM_FLUTTER_VIEW_H_ */
