// Copyright 2021 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef FLUTTER_TIZEN_EMBEDDING_CPP_TIZEN_LOG_H_
#define FLUTTER_TIZEN_EMBEDDING_CPP_TIZEN_LOG_H_

#include <dlog.h>

#include <cstdarg>

class TizenLog {
 public:
  static inline const char *tag = "ConsoleMessage";

  static void Debug(const char *format, ...) {
    va_list args;
    va_start(args, format);
    dlog_vprint(DLOG_DEBUG, tag, format, args);
    va_end(args);
  }

  static void Info(const char *format, ...) {
    va_list args;
    va_start(args, format);
    dlog_vprint(DLOG_INFO, tag, format, args);
    va_end(args);
  }

  static void Warn(const char *format, ...) {
    va_list args;
    va_start(args, format);
    dlog_vprint(DLOG_WARN, tag, format, args);
    va_end(args);
  }

  static void Error(const char *format, ...) {
    va_list args;
    va_start(args, format);
    dlog_vprint(DLOG_ERROR, tag, format, args);
    va_end(args);
  }

 private:
  explicit TizenLog() {}
  virtual ~TizenLog() {}
};

#endif /* FLUTTER_TIZEN_EMBEDDING_CPP_TIZEN_LOG_H_ */
