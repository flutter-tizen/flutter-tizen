// Copyright 2022 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef FLUTTER_TIZEN_EMBEDDING_CPP_INCLUDE_ELM_FLUTTER_VIEW_H_
#define FLUTTER_TIZEN_EMBEDDING_CPP_INCLUDE_ELM_FLUTTER_VIEW_H_

#include <Elementary.h>
#include <flutter/plugin_registry.h>
#include <flutter_tizen.h>

#include <memory>
#include <string>
#include <vector>

#include "flutter_engine.h"

// Displays a Flutter screen in a Tizen application.
class ElmFlutterView {
 public:
  explicit ElmFlutterView(Evas_Object *parent) : parent_(parent) {}

  explicit ElmFlutterView(Evas_Object *parent, int32_t initial_width,
                          int32_t initial_height)
      : parent_(parent),
        initial_width_(initial_width),
        initial_height_(initial_height) {}

  virtual ~ElmFlutterView();

  // Whether the view is running.
  bool IsRunning() { return view_ != nullptr; }

  Evas_Object *evas_object() { return evas_object_; }

  FlutterEngine *engine() { return engine_.get(); }

  // Sets an engine associated with this view.
  void SetEngine(std::unique_ptr<FlutterEngine> engine) {
    engine_ = std::move(engine);
  }

  // Starts running the view with the associated engine, creating if not set.
  bool RunEngine();

  // Resizes the view.
  void Resize(int32_t width, int32_t height);

  // The current width of the view.
  int32_t GetWidth();

  // The current height of the view.
  int32_t GetHeight();

 private:
  // The Flutter engine instance.
  std::unique_ptr<FlutterEngine> engine_;

  // The Flutter view instance handle.
  FlutterDesktopViewRef view_ = nullptr;

  // The backing Evas object for this view.
  Evas_Object *evas_object_ = nullptr;

  // The parent of |evas_object_|.
  Evas_Object *parent_ = nullptr;

  // The initial width of the view.
  //
  // Defaults to the parent width if the value is zero.
  int32_t initial_width_ = 0;

  // The initial height of the view.
  //
  // Defaults to the parent height if the value is zero.
  int32_t initial_height_ = 0;
};

#endif /* FLUTTER_TIZEN_EMBEDDING_CPP_INCLUDE_ELM_FLUTTER_VIEW_H_ */
