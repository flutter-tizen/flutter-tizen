// Copyright 2021 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

using System;
using System.Collections.Generic;
using System.Diagnostics;
using Tizen.Applications;
using static Tizen.Flutter.Embedding.Interop;

namespace Tizen.Flutter.Embedding
{
    /// <summary>
    /// The <see cref="ServiceApplication"/> variant of <see cref="FlutterApplication"/>.
    /// </summary>
    public class FlutterServiceApplication : ServiceApplication, IPluginRegistry
    {
        /// <summary>
        /// The switches to pass to the Flutter engine.
        /// Custom switches may be added before <see cref="OnCreate"/> is called.
        /// </summary>
        protected List<string> EngineArgs { get; } = new List<string>();

        /// <summary>
        /// The optional entrypoint in the Dart project. If the value is empty, defaults to main().
        /// </summary>
        protected string DartEntrypoint { get; set; } = string.Empty;

        /// <summary>
        /// The list of Dart entrypoint arguments.
        /// </summary>
        protected List<string> DartEntrypointArgs { get; } = new List<string>();

        /// <summary>
        /// The Flutter engine instance handle.
        /// </summary>
        protected FlutterDesktopEngine Handle { get; private set; } = new FlutterDesktopEngine();

        public override void Run(string[] args)
        {
            // Log any unhandled exception.
            AppDomain.CurrentDomain.UnhandledException += (s, e) =>
            {
                var exception = e.ExceptionObject as Exception;
                TizenLog.Error($"Unhandled exception: {exception}");
            };

            base.Run(args);
        }

        protected override void OnCreate()
        {
            base.OnCreate();

            var windowProperties = new FlutterDesktopWindowProperties
            {
                headed = false,
            };

            Utils.ParseEngineArgs(EngineArgs);

            using var switches = new StringArray(EngineArgs);
            using var entrypointArgs = new StringArray(DartEntrypointArgs);
            var engineProperties = new FlutterDesktopEngineProperties
            {
                assets_path = "../res/flutter_assets",
                icu_data_path = "../res/icudtl.dat",
                aot_library_path = "../lib/libapp.so",
                switches = switches.Handle,
                switches_count = (uint)switches.Length,
                entrypoint = DartEntrypoint,
                dart_entrypoint_argc = entrypointArgs.Length,
                dart_entrypoint_argv = entrypointArgs.Handle,
            };

            Handle = FlutterDesktopRunEngine(ref windowProperties, ref engineProperties);
            if (Handle.IsInvalid)
            {
                throw new Exception("Could not launch a service application.");
            }
        }

        protected override void OnTerminate()
        {
            base.OnTerminate();

            Debug.Assert(Handle);

            FlutterDesktopShutdownEngine(Handle);
        }

        protected override void OnLowMemory(LowMemoryEventArgs e)
        {
            base.OnLowMemory(e);

            Debug.Assert(Handle);

            FlutterDesktopNotifyLowMemoryWarning(Handle);
        }

        protected override void OnLocaleChanged(LocaleChangedEventArgs e)
        {
            base.OnLocaleChanged(e);

            Debug.Assert(Handle);

            FlutterDesktopNotifyLocaleChange(Handle);
        }

        protected override void OnRegionFormatChanged(RegionFormatChangedEventArgs e)
        {
            base.OnRegionFormatChanged(e);

            Debug.Assert(Handle);

            FlutterDesktopNotifyLocaleChange(Handle);
        }

        /// <summary>
        /// Returns the plugin registrar handle for the plugin with the given name.
        /// The name must be unique across the application.
        /// </summary>
        public FlutterDesktopPluginRegistrar GetRegistrarForPlugin(string pluginName)
        {
            if (Handle)
            {
                return FlutterDesktopGetPluginRegistrar(Handle, pluginName);
            }
            return new FlutterDesktopPluginRegistrar();
        }
    }
}
