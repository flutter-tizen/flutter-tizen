// Copyright 2022 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

namespace Tizen.Flutter.Embedding
{
    internal class FlutterDotnetPluginRegistrar : IFlutterPluginRegistrar
    {
        private IPluginRegistry _registry;

        public FlutterDotnetPluginRegistrar(IPluginRegistry registry)
        {
            _registry = registry;
        }

        /// <summary>
        /// Registers a dotnet plugin implementing the <see cref="IFlutterPlugin"/> interface.
        /// When the plugin is registered, the <see cref="IFlutterPlugin.OnAttachedToEngine"/> method is called.
        /// </summary>
        public void RegisterPlugin(IFlutterPlugin plugin)
        {
            if (plugin != null)
            {
                FlutterDesktopPluginRegistrar registrar = _registry.GetRegistrarForPlugin(plugin.GetType().FullName);
                FlutterDotnetPluginRegistry.Instance.AddPlugin(registrar, plugin);
            }
        }
    }

    public static class PluginRegistryExtensions
    {
        public static IFlutterPluginRegistrar GetRegistrarForDotnetPlugin(this IPluginRegistry registry)
        {
            return new FlutterDotnetPluginRegistrar(registry);
        }
    }
}
