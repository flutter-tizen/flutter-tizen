// Copyright 2022 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef FLUTTER_TIZEN_EMBEDDING_CPP_UTILS_H_
#define FLUTTER_TIZEN_EMBEDDING_CPP_UTILS_H_

#include <string>
#include <vector>

class Utils {
 public:
  // Reads engine arguments passed from the flutter-tizen tool and adds to
  // |list|.
  static void ParseEngineArgs(std::vector<std::string>* list);
};

#endif /* FLUTTER_TIZEN_EMBEDDING_CPP_UTILS_H_ */
