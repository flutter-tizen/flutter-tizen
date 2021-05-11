// Copyright 2021 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

using System;

namespace Tizen.Flutter.Embedding
{
    public interface IPluginRegistry
    {
        public FlutterDesktopPluginRegistrar GetRegistrarForPlugin(string pluginName);
    }
}
