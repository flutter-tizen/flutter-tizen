// Copyright 2022 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

using System;
using System.Collections.Concurrent;

namespace Tizen.Flutter.Embedding
{
    internal class FlutterDotnetPluginRegistry
    {
        private static readonly Lazy<FlutterDotnetPluginRegistry> _instance
            = new Lazy<FlutterDotnetPluginRegistry>(() => new FlutterDotnetPluginRegistry());

        public static FlutterDotnetPluginRegistry Instance => _instance.Value;

        private readonly ConcurrentDictionary<int, IFlutterPlugin> _plugins = new ConcurrentDictionary<int, IFlutterPlugin>();

        private FlutterDotnetPluginRegistry()
        {
        }

        public bool HasPlugin(IFlutterPlugin plugin)
        {
            return plugin != null && _plugins.ContainsKey(plugin.GetHashCode());
        }

        public void AddPlugin(FlutterDesktopPluginRegistrar registrar, IFlutterPlugin plugin)
        {
            if (plugin == null)
            {
                throw new ArgumentNullException(nameof(plugin));
            }

            if (_plugins.TryAdd(plugin.GetHashCode(), plugin))
            {
                plugin.OnAttachedToEngine(new FlutterDotnetPluginBinding(registrar));
            }
        }

        public void RemovePlugin(IFlutterPlugin plugin)
        {
            if (plugin == null)
            {
                throw new ArgumentNullException(nameof(plugin));
            }

            if (_plugins.TryRemove(plugin.GetHashCode(), out IFlutterPlugin removedPlugin))
            {
                removedPlugin.OnDetachedFromEngine();
            }
        }

        public void RemoveAllPlugins()
        {
            foreach (var plugin in _plugins)
            {
                plugin.Value.OnDetachedFromEngine();
            }
            _plugins.Clear();
        }
    }
}
