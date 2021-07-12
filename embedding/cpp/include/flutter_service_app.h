// Copyright 2021 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef FLUTTER_TIZEN_EMBEDDING_CPP_INCLUDE_FLUTTER_SERVICE_APP_H_
#define FLUTTER_TIZEN_EMBEDDING_CPP_INCLUDE_FLUTTER_SERVICE_APP_H_

#include <service_app.h>

#include "flutter_app.h"

// The app base class for headless execution.
class FlutterServiceApp : public FlutterApp {
 public:
  explicit FlutterServiceApp();
  virtual ~FlutterServiceApp() {}

  virtual int Run(int argc, char **argv) override;
};

#endif /* FLUTTER_TIZEN_EMBEDDING_CPP_INCLUDE_FLUTTER_SERVICE_APP_H_ */
