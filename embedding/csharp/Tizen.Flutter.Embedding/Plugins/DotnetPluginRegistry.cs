// Copyright 2022 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

using System;
using System.Collections.Concurrent;

namespace Tizen.Flutter.Embedding
{
    /// <summary>
    /// A registry for dotnet plugins implementing the <see cref="IFlutterPlugin"/> interface.
    /// </summary>
    /// <remarks>
    /// When the plugin is registered, the <see cref="IFlutterPlugin.OnAttachedToEngine"/> method is called.
    /// The registered plugin is automatically unregistered with the <see cref="IFlutterPlugin.OnDetachedFromEngine"/>
    /// method call when the Flutter engine is detached.
    /// </remarks>
    public class DotnetPluginRegistry
    {
        private static readonly Lazy<DotnetPluginRegistry> _instance
            = new Lazy<DotnetPluginRegistry>(() => new DotnetPluginRegistry());

        private readonly ConcurrentDictionary<int, IFlutterPlugin> _plugins = new ConcurrentDictionary<int, IFlutterPlugin>();

        private DotnetPluginRegistry()
        {
        }

        /// <summary>
        /// Gets the singleton instance of the <see cref="DotnetPluginRegistry"/>.
        /// </summary>
        public static DotnetPluginRegistry Instance => _instance.Value;

        /// <summary>
        /// Returns whether the plugin is registered.
        /// </summary>
        public bool HasPlugin(IFlutterPlugin plugin)
        {
            return plugin != null && _plugins.ContainsKey(plugin.GetHashCode());
        }

        /// <summary>
        /// Adds a dotnet plugin.
        /// </summary>
        public void AddPlugin(IFlutterPlugin plugin)
        {
            if (plugin == null)
            {
                throw new ArgumentNullException(nameof(plugin));
            }

            if (_plugins.TryAdd(plugin.GetHashCode(), plugin))
            {
                plugin.OnAttachedToEngine(new FlutterPluginBindingImpl());
            }
        }

        /// <summary>
        /// Removes an added dotnet plugin.
        /// </summary>
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

        /// <summary>
        /// Removes all added dotnet plugins.
        /// </summary>
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
