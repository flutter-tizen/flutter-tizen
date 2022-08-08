// Copyright 2022 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "include/elm_flutter_view.h"

#include <cassert>

#include "include/flutter_engine.h"
#include "tizen_log.h"

ElmFlutterView::~ElmFlutterView() {
  if (view_) {
    FlutterDesktopViewDestroy(view_);
    engine_ = nullptr;
    view_ = nullptr;
  }
}

bool ElmFlutterView::RunEngine() {
  if (IsRunning()) {
    TizenLog::Error("The engine is already running.");
    return false;
  }

  if (!parent_) {
    TizenLog::Error("The parent object is invalid.");
    return false;
  }

  if (!engine_) {
    engine_ = FlutterEngine::Create();
  }

  if (!engine_) {
    TizenLog::Error("Could not create a Flutter engine.");
    return false;
  }

  FlutterDesktopViewProperties view_prop = {};
  view_prop.width = initial_width_;
  view_prop.height = initial_height_;

  view_ = FlutterDesktopViewCreateFromElmParent(
      view_prop, engine_->RelinquishEngine(), parent_);
  if (!view_) {
    TizenLog::Error("Could not launch a Flutter view.");
    return false;
  }

  evas_object_ =
      static_cast<Evas_Object *>(FlutterDesktopViewGetNativeHandle(view_));
  if (!evas_object_) {
    TizenLog::Error("Could not get an Evas object.");
    return false;
  }

  return true;
}

void ElmFlutterView::Resize(int32_t width, int32_t height) {
  assert(IsRunning());

  int32_t view_width = width, view_height = height;
  evas_object_geometry_get(evas_object_, nullptr, nullptr, &view_width,
                           &view_height);
  if (view_width != width || view_height != height) {
    FlutterDesktopViewResize(view_, width, height);
  }
}

int32_t ElmFlutterView::GetWidth() {
  assert(IsRunning());

  int32_t width = 0;
  evas_object_geometry_get(evas_object_, nullptr, nullptr, &width, nullptr);
  return width;
}

int32_t ElmFlutterView::GetHeight() {
  assert(IsRunning());

  int32_t height = 0;
  evas_object_geometry_get(evas_object_, nullptr, nullptr, nullptr, &height);
  return height;
}
