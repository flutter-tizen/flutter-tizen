// Copyright 2021 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

namespace Tizen.Flutter.Embedding
{
    public interface IPluginRegistry
    {
        /// <summary>
        /// Returns the plugin registrar handle for the plugin with the given name.
        /// The name must be unique across the application.
        /// </summary>
        FlutterDesktopPluginRegistrar GetRegistrarForPlugin(string pluginName);
    }
}
