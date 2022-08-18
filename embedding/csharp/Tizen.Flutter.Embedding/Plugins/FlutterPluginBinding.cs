// Copyright 2022 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

namespace Tizen.Flutter.Embedding
{
    /// <summary>
    /// An interface for providing required stuff for Flutter plugins.
    /// </summary>
    /// <remarks>
    /// This interface is used by Flutter plugins to access the Flutter engine.
    /// Currently, only <see cref="IBinaryMessenger"/> is supported, but more interfaces may be added in the future.
    /// </remarks>
    public interface IFlutterPluginBinding
    {
        IBinaryMessenger BinaryMessenger { get; }
    }

    internal class FlutterPluginBindingImpl : IFlutterPluginBinding
    {
        public IBinaryMessenger BinaryMessenger => DefaultBinaryMessenger.Instance;
    }
}
