// Copyright 2020 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

using System;
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
        /// The optional entrypoint in the Dart project. Defaults to main() if the value is empty.
        /// </summary>
        public string DartEntrypoint { get; set; } = string.Empty;

        /// <summary>
        /// Whether the app has started.
        /// </summary>
        public bool IsRunning => View != null;

        /// <summary>
        /// The Flutter engine instance.
        /// </summary>
        internal FlutterEngine Engine { get; private set; } = null;

        /// <summary>
        /// The Flutter view instance handle.
        /// </summary>
        protected internal FlutterDesktopView View { get; private set; } = new FlutterDesktopView();

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
        /// If true, the "http://tizen.org/privilege/window.priority.set" privilege must be added to tizen-manifest.xml
        /// file.
        /// </summary>
        protected bool IsTopLevel { get; set; } = false;

        /// <summary>
        /// Whether the app should support pointing devices (mouse).
        /// If false, pointing device input will not work and and the D-PAD will show with the floating menu.
        /// If true and IsFloatingMenuSupport is false, pointing device input will not work.
        /// 
        /// It only works on TV.
        /// </summary>
        protected bool IsPointingDeviceSupport { get; set; } = true;

        /// <summary>
        /// Whether the app should support floating menus.
        /// If false, pointing device input will not work and the floating menu will not be displayed.
        /// If false and IsPointingDeviceSupport is true, pointing device input will not work.
        /// 
        /// It only works on TV.
        /// </summary>
        protected bool IsFloatingMenuSupport { get; set; } = true;

        /// <summary>
        /// The renderer type of the engine. Defaults to EGL.
        /// </summary>
        protected FlutterRendererType RendererType { get; set; } = FlutterRendererType.EGL;

        /// <summary>
        /// The user-defined pixel ratio. Defaults to the device pixel ratio if the value is 0.
        /// </summary>
        protected double UserPixelRatio { get; set; } = 0.0;

        /// <InheritDoc/>
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

        /// <InheritDoc/>
        public FlutterDesktopPluginRegistrar GetRegistrarForPlugin(string pluginName)
        {
            if (IsRunning)
            {
                return Engine.GetRegistrarForPlugin(pluginName);
            }
            return new FlutterDesktopPluginRegistrar();
        }

        /// <InheritDoc/>
        protected override void OnCreate()
        {
            base.OnCreate();

            Engine = new FlutterEngine(DartEntrypoint);
            if (!Engine.IsValid)
            {
                throw new Exception("Could not create a Flutter engine.");
            }

            if (RendererType == FlutterRendererType.EvasGL && Engine.Arguments.IsImpellerEnabled)
            {
                throw new Exception("Impeller is not supported by FlutterRendererType::kEvasGL type renderer.");
            }

            if (Engine.Arguments.IsFlutterGpuEnabled && !Engine.Arguments.IsImpellerEnabled)
            {
                throw new Exception("flutter_gpu requires Impeller. Enable Impeller using the --enable-impeller flag.");
            }

            var daliApp = ApplicationNewManual4(0, "", "", 1 /* transparent */);
            var daliWindow = GetWindow(daliApp);
            IntPtr wlWindow = IntPtr.Zero;
            if (HasBody(daliWindow))
            {
                wlWindow = GetNativeWindowHandler(daliWindow);
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
                renderer_type = (FlutterDesktopRendererType)RendererType,
                user_pixel_ratio = UserPixelRatio < 0.0 ? 0.0 : UserPixelRatio,
                window_handle = wlWindow,
                pointing_device_support = IsPointingDeviceSupport,
                floating_menu_support = IsFloatingMenuSupport,
            };

            View = FlutterDesktopViewCreateFromNewWindow(ref windowProperties, Engine.Engine);
            if (View.IsInvalid)
            {
                throw new Exception("Could not launch a Flutter application.");
            }
        }

        /// <InheritDoc/>
        protected override void OnResume()
        {
            base.OnResume();

            Debug.Assert(IsRunning);

            Engine.NotifyAppIsResumed();
        }

        /// <InheritDoc/>
        protected override void OnPause()
        {
            base.OnPause();

            Debug.Assert(IsRunning);

            Engine.NotifyAppIsPaused();
        }

        /// <InheritDoc/>
        protected override void OnTerminate()
        {
            base.OnTerminate();

            Debug.Assert(IsRunning);

            Engine.NotifyAppIsDetached();

            DotnetPluginRegistry.Instance.RemoveAllPlugins();
            FlutterDesktopViewDestroy(View);
            Engine = null;
            View = null;
        }

        /// <InheritDoc/>
        protected override void OnAppControlReceived(AppControlReceivedEventArgs e)
        {
            Debug.Assert(IsRunning);

            Engine.NotifyAppControl(e.ReceivedAppControl);
        }

        /// <InheritDoc/>
        protected override void OnLowMemory(LowMemoryEventArgs e)
        {
            base.OnLowMemory(e);

            Debug.Assert(IsRunning);

            Engine.NotifyLowMemoryWarning();
        }

        /// <InheritDoc/>
        protected override void OnLocaleChanged(LocaleChangedEventArgs e)
        {
            base.OnLocaleChanged(e);

            Debug.Assert(IsRunning);

            Engine.NotifyLocaleChange();
        }

        /// <InheritDoc/>
        protected override void OnRegionFormatChanged(RegionFormatChangedEventArgs e)
        {
            base.OnRegionFormatChanged(e);

            Debug.Assert(IsRunning);

            Engine.NotifyLocaleChange();
        }
    }
}
