// Copyright 2020 Samsung Electronics Co., Ltd. All rights reserved.
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
    /// The application base class which creates and manages the Flutter engine instance.
    /// </summary>
    public class FlutterApplication : CoreUIApplication, IPluginRegistry
    {
        /// <summary>
        /// The x-coordinate of the top left corner of the window.
        /// </summary>
        protected int WindowOffsetX { get; set; } = 0;

        /// <summary>
        /// The y-coordinate of the top left corner of the window.
        /// </summary>
        protected int WindowOffsetY { get; set; } = 0;

        /// <summary>
        /// The width of the window, or the maximum width if the value is zero.
        /// </summary>
        protected int WindowWidth { get; set; } = 0;

        /// <summary>
        /// The height of the window, or the maximum height if the value is zero.
        /// </summary>
        protected int WindowHeight { get; set; } = 0;

        /// <summary>
        /// Whether the window should have a transparent background or not.
        /// </summary>
        protected bool IsWindowTransparent { get; set; } = false;

        /// <summary>
        /// Whether the window should be focusable or not.
        /// </summary>
        protected bool IsWindowFocusable { get; set; } = true;

        /// <summary>
        /// Whether the app should be displayed over other apps.
        /// If true, the "http://tizen.org/privilege/window.priority.set" privilege must be added to tizen-manifest.xml file.
        /// </summary>
        protected bool IsTopLevel { get; set; } = false;

        /// <summary>
        /// The switches to pass to the Flutter engine.
        /// Custom switches may be added before <see cref="OnCreate"/> is called.
        /// </summary>
        protected List<string> EngineArgs { get; } = new List<string>();

        /// <summary>
        /// The optional entrypoint in the Dart project. If the value is empty, defaults to main().
        /// </summary>
        public string DartEntrypoint { get; set; } = string.Empty;

        /// <summary>
        /// The list of Dart entrypoint arguments.
        /// </summary>
        protected List<string> DartEntrypointArgs { get; } = new List<string>();

        /// <summary>
        /// The Flutter engine instance handle.
        /// </summary>
        protected internal FlutterDesktopEngine Engine { get; private set; } = new FlutterDesktopEngine();

        /// <summary>
        /// The Flutter view instance handle.
        /// </summary>
        protected internal FlutterDesktopView View { get; private set; } = new FlutterDesktopView();

        public override void Run(string[] args)
        {
            DartEntrypointArgs.AddRange(args);

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

            Utils.ParseEngineArgs(EngineArgs);

            using (var switches = new StringArray(EngineArgs))
            using (var entrypointArgs = new StringArray(DartEntrypointArgs))
            {
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

                Engine = FlutterDesktopEngineCreate(ref engineProperties);
                if (Engine.IsInvalid)
                {
                    throw new Exception("Could not create a Flutter engine.");
                }
            }

            var windowProperties = new FlutterDesktopWindowProperties
            {
                x = WindowOffsetX,
                y = WindowOffsetY,
                width = WindowWidth,
                height = WindowHeight,
                transparent = IsWindowTransparent,
                focusable = IsWindowFocusable,
                top_level = IsTopLevel,
            };

            View = FlutterDesktopViewCreateFromNewWindow(ref windowProperties, Engine);
            if (View.IsInvalid)
            {
                throw new Exception("Could not launch a Flutter application.");
            }
        }

        protected override void OnResume()
        {
            base.OnResume();

            Debug.Assert(Engine);

            FlutterDesktopEngineNotifyAppIsResumed(Engine);
        }

        protected override void OnPause()
        {
            base.OnPause();

            Debug.Assert(Engine);

            FlutterDesktopEngineNotifyAppIsPaused(Engine);
        }

        protected override void OnTerminate()
        {
            base.OnTerminate();

            Debug.Assert(Engine);

            DotnetPluginRegistry.Instance.RemoveAllPlugins();
            FlutterDesktopEngineShutdown(Engine);
        }

        protected override void OnAppControlReceived(AppControlReceivedEventArgs e)
        {
            Debug.Assert(Engine);

            FlutterDesktopEngineNotifyAppControl(Engine, e.ReceivedAppControl.SafeAppControlHandle);
        }

        protected override void OnLowMemory(LowMemoryEventArgs e)
        {
            base.OnLowMemory(e);

            Debug.Assert(Engine);

            FlutterDesktopEngineNotifyLowMemoryWarning(Engine);
        }

        protected override void OnLocaleChanged(LocaleChangedEventArgs e)
        {
            base.OnLocaleChanged(e);

            Debug.Assert(Engine);

            FlutterDesktopEngineNotifyLocaleChange(Engine);
        }

        protected override void OnRegionFormatChanged(RegionFormatChangedEventArgs e)
        {
            base.OnRegionFormatChanged(e);

            Debug.Assert(Engine);

            FlutterDesktopEngineNotifyLocaleChange(Engine);
        }

        /// <summary>
        /// Returns the plugin registrar handle for the plugin with the given name.
        /// The name must be unique across the application.
        /// </summary>
        public FlutterDesktopPluginRegistrar GetRegistrarForPlugin(string pluginName)
        {
            if (Engine)
            {
                return FlutterDesktopEngineGetPluginRegistrar(Engine, pluginName);
            }
            return new FlutterDesktopPluginRegistrar();
        }
    }
}
