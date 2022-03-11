// Copyright 2022 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

namespace Tizen.Flutter.Embedding
{
    public interface IFlutterPluginRegistrar
    {
        /// <summary>
        /// Registers a plugin implementing the <see cref="IFlutterPlugin"/> interface.
        /// </summary>
        /// <remarks>
        /// When the plugin is registered, the <see cref="IFlutterPlugin.OnAttachedToEngine"/> method is called.
        /// The registered plugin is automatically unregistered with the <see cref="IFlutterPlugin.OnDetachedFromEngine"/> 
        /// method call when the Flutter engine is detached.
        /// </remarks>
        void RegisterPlugin(IFlutterPlugin plugin);
    }
}
