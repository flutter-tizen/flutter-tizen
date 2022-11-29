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
        /// <summary>
        /// Creates a <see cref="FlutterException"/> with the given properties.
        /// </summary>
        public FlutterException(string code, string message, object details) : base(message)
        {
            Code = code;
            Details = details;
        }

        /// <summary>
        /// The error code.
        /// </summary>
        public string Code { get; }

        /// <summary>
        /// The error details.
        /// </summary>
        public object Details { get; }
    }
}
