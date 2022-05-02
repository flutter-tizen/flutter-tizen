// Copyright 2022 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "utils.h"

#include <app.h>

#include "tizen_log.h"

void Utils::ParseEngineArgs(std::vector<std::string> *list) {
  char *app_id;
  if (app_get_id(&app_id) != 0) {
    TizenLog::Warn("App id is not found.");
    return;
  }
  std::string temp_path("/home/owner/share/tmp/sdk_tools/" +
                        std::string(app_id) + ".rpm");
  free(app_id);

  auto file = fopen(temp_path.c_str(), "r");
  if (!file) {
    return;
  }
  char *line = nullptr;
  size_t len = 0;

  while (getline(&line, &len, file) > 0) {
    if (line[strlen(line) - 1] == '\n') {
      line[strlen(line) - 1] = 0;
    }
    TizenLog::Info("Enabled: %s", line);
    list->push_back(line);
  }
  free(line);
  fclose(file);

  if (remove(temp_path.c_str()) != 0) {
    TizenLog::Warn("Error removing file: %s", strerror(errno));
  }
}