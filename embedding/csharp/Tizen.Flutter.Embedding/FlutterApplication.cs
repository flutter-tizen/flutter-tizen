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
    /// Enumeration for the renderer type of the engine.
    /// </summary>
    public enum FlutterRendererType
    {
        /// <summary>
        /// The renderer based on EvasGL.
        /// </summary>
        EvasGL = 0,
        /// <summary>
        /// The renderer based on EGL.
        /// </summary>
        EGL,
    }

    /// <summary>
    /// The app base class for headed Flutter execution.
    /// </summary>
    public class FlutterApplication : CoreUIApplication, IPluginRegistry
    {
        /// <summary>
        /// Initialize FlutterApplication.
        /// </summary>
        public FlutterApplication()
        {
#if WEARABLE_PROFILE
            RendererType = FlutterRendererType.EvasGL;
#endif
        }

        /// <summary>
        /// The x-coordinate of the top left corner of the window.
        /// </summary>
        protected int WindowOffsetX { get; set; } = 0;

        /// <summary>
        /// The y-coordinate of the top left corner of the window.
        /// </summary>
        protected int WindowOffsetY { get; set; } = 0;

        /// <summary>
        /// The width of the window. Defaults to the screen width if the value is zero.
        /// </summary>
        protected int WindowWidth { get; set; } = 0;

        /// <summary>
        /// The height of the window. Defaults to the screen height if the value is zero.
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
        /// The renderer type of the engine. Defaults to EGL. If the profile is wearable, defaults to EvasGL.
        /// </summary>
        protected FlutterRendererType RendererType { get; set; } = FlutterRendererType.EGL;

        /// <summary>
        /// The optional entrypoint in the Dart project. Defaults to main() if the value is empty.
        /// </summary>
        public string DartEntrypoint { get; set; } = string.Empty;

        /// <summary>
        /// The list of Dart entrypoint arguments.
        /// </summary>
        private List<string> DartEntrypointArgs { get; } = new List<string>();

        /// <summary>
        /// The Flutter engine instance.
        /// </summary>
        internal FlutterEngine Engine { get; private set; } = null;

        /// <summary>
        /// The Flutter view instance handle.
        /// </summary>
        protected internal FlutterDesktopView View { get; private set; } = new FlutterDesktopView();

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

            Engine = new FlutterEngine(DartEntrypoint, DartEntrypointArgs);
            if (!Engine.IsValid)
            {
                throw new Exception("Could not create a Flutter engine.");
            }

#if WEARABLE_PROFILE
            if (RendererType ==  FlutterRendererType.EGL)
            {
                throw new Exception("FlutterRendererType.kEGL is not supported by this profile.");
            }
#endif
            var windowProperties = new FlutterDesktopWindowProperties
            {
                x = WindowOffsetX,
                y = WindowOffsetY,
                width = WindowWidth,
                height = WindowHeight,
                transparent = IsWindowTransparent,
                focusable = IsWindowFocusable,
                top_level = IsTopLevel,
                renderer_type = (FlutterDesktopRendererType)RendererType,
            };

            View = FlutterDesktopViewCreateFromNewWindow(ref windowProperties, Engine.Engine);
            if (View.IsInvalid)
            {
                throw new Exception("Could not launch a Flutter application.");
            }
        }

        protected override void OnResume()
        {
            base.OnResume();

            Debug.Assert(Engine.IsValid);

            Engine.NotifyAppIsResumed();
        }

        protected override void OnPause()
        {
            base.OnPause();

            Debug.Assert(Engine.IsValid);

            Engine.NotifyAppIsPaused();
        }

        protected override void OnTerminate()
        {
            base.OnTerminate();

            Debug.Assert(Engine.IsValid);

            DotnetPluginRegistry.Instance.RemoveAllPlugins();
            FlutterDesktopViewDestroy(View);
            Engine = null;
            View = null;
        }

        protected override void OnAppControlReceived(AppControlReceivedEventArgs e)
        {
            Debug.Assert(Engine.IsValid);

            Engine.NotifyAppControl(e.ReceivedAppControl);
        }

        protected override void OnLowMemory(LowMemoryEventArgs e)
        {
            base.OnLowMemory(e);

            Debug.Assert(Engine.IsValid);

            Engine.NotifyLowMemoryWarning();
        }

        protected override void OnLocaleChanged(LocaleChangedEventArgs e)
        {
            base.OnLocaleChanged(e);

            Debug.Assert(Engine.IsValid);

            Engine.NotifyLocaleChange();
        }

        protected override void OnRegionFormatChanged(RegionFormatChangedEventArgs e)
        {
            base.OnRegionFormatChanged(e);

            Debug.Assert(Engine.IsValid);

            Engine.NotifyLocaleChange();
        }

        /// <summary>
        /// Returns the plugin registrar handle for the plugin with the given name.
        /// The name must be unique across the application.
        /// </summary>
        public FlutterDesktopPluginRegistrar GetRegistrarForPlugin(string pluginName)
        {
            if (Engine.IsValid)
            {
                return Engine.GetRegistrarForPlugin(pluginName);
            }
            return new FlutterDesktopPluginRegistrar();
        }
    }
}
