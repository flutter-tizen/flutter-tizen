// Copyright 2021 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

using System.Runtime.CompilerServices;

namespace Tizen.Flutter.Embedding
{
    internal class TizenLog
    {
        public const string LogTag = "ConsoleMessage";

        public static void Debug(
            string message,
            [CallerFilePath] string file = "",
            [CallerMemberName] string func = "",
            [CallerLineNumber] int line = 0)
        {
            InternalLog.Debug(LogTag, message, file, func, line);
        }

        public static void Info(
            string message,
            [CallerFilePath] string file = "",
            [CallerMemberName] string func = "",
            [CallerLineNumber] int line = 0)
        {
            InternalLog.Info(LogTag, message, file, func, line);
        }

        public static void Warn(
            string message,
            [CallerFilePath] string file = "",
            [CallerMemberName] string func = "",
            [CallerLineNumber] int line = 0)
        {
            InternalLog.Warn(LogTag, message, file, func, line);
        }

        public static void Error(
            string message,
            [CallerFilePath] string file = "",
            [CallerMemberName] string func = "",
            [CallerLineNumber] int line = 0)
        {
            InternalLog.Error(LogTag, message, file, func, line);
        }
    }
}
