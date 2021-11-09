// Copyright 2021 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

using System;

namespace Tizen.Flutter.Embedding
{
    /// <summary>
    /// Thrown to indicate that a platform interaction failed to find a handling plugin.
    /// </summary>
    public class MissingPluginException : Exception
    {
        public MissingPluginException() : base()
        {
        }

        public MissingPluginException(string message) : base(message)
        {
        }
    }
}
