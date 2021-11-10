// Copyright 2021 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

using System;

namespace Tizen.Flutter.Embedding
{
    /// <summary>
    /// Thrown to indicate that a Flutter method invocation failed on the Flutter side.
    /// </summary>
    public class FlutterException : Exception
    {
        public FlutterException(string code, string message, object details) : base(message)
        {
            Code = code;
            Details = details;
        }

        public string Code { get; }

        public object Details { get; }
    }
}
