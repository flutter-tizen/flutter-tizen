// Copyright 2021 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

using System;

namespace Tizen.Flutter.Embedding
{
    /// <summary>
    /// Command object representing a method call on a <see cref="MethodChannel"/>.
    /// </summary>
    public class MethodCall
    {
        /// <summary>
        /// Creates a <see cref="MethodCall"/> with the specified method name and arguments.
        /// </summary>
        /// <param name="method">The method name String, not null.</param>
        /// <param name="arguments">The arguments, a value supported by the channel's message codec.</param>
        public MethodCall(string method, object arguments)
        {
            Method = method ?? throw new ArgumentNullException(nameof(method));
            Arguments = arguments;
        }

        /// <summary>
        /// The name of the called method.
        /// </summary>
        public string Method { get; }

        /// <summary>
        /// Arguments for the call.
        /// </summary>
        public object Arguments { get; }
    }
}
