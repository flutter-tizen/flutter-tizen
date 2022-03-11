// Copyright 2022 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

namespace Tizen.Flutter.Embedding
{
    /// <summary>
    /// Interface to be implemented by all Flutter plugins.
    /// </summary>
    public interface IFlutterPlugin
    {
        /// <summary>
        /// Called when the plugin is registered with the Flutter engine.
        /// </summary>
        void OnAttachedToEngine(IFlutterPluginBinding binding);

        /// <summary>
        /// Called when the plugin is unreigstered from the Flutter engine.
        /// </summary>
        void OnDetachedFromEngine();
    }
}
