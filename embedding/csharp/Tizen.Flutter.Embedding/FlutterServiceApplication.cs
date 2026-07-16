// Copyright 2021 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

using System;
using System.Diagnostics;
using Tizen.Applications;

namespace Tizen.Flutter.Embedding
{
    /// <summary>
    /// The app base class for headless Flutter execution.
    /// </summary>
    public class FlutterServiceApplication : ServiceApplication, IPluginRegistry
    {
        /// <summary>
        /// The optional entrypoint in the Dart project. Defaults to main() if the value is empty.
        /// </summary>
        public string DartEntrypoint { get; set; } = string.Empty;

        /// <summary>
        /// The thread policy for running the UI isolate. Defaults to <see cref="FlutterUIThreadPolicy.Default"/>,
        /// which merges the UI isolate onto the platform thread. If the UI isolate is blocked by a long-running
        /// synchronous native call (e.g. via FFI), the platform thread can no longer respond to the Tizen app
        /// framework (app control/resume requests), which may cause the app to be killed by the platform watchdog.
        ///
        /// <see cref="FlutterUIThreadPolicy.RunOnSeparateThread"/> is available for apps that need it, but apps
        /// must still make sure their Dart code never blocks indefinitely, whichever policy is used. Apps that
        /// choose this policy are responsible for any issues that result from doing so.
        /// </summary>
        protected FlutterUIThreadPolicy UIThreadPolicy { get; set; } = FlutterUIThreadPolicy.Default;

        /// <summary>
        /// Whether the app has started.
        /// </summary>
        public bool IsRunning => Engine != null;

        /// <summary>
        /// The Flutter engine instance.
        /// </summary>
        internal FlutterEngine Engine { get; private set; } = null;

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

            Engine = new FlutterEngine(DartEntrypoint, uiThreadPolicy: UIThreadPolicy);
            if (!Engine.IsValid)
            {
                throw new Exception("Could not create a Flutter engine.");
            }

            if (!Engine.Run())
            {
                throw new Exception("Could not run a Flutter engine.");
            }
        }

        /// <InheritDoc/>
        protected override void OnTerminate()
        {
            base.OnTerminate();

            Debug.Assert(IsRunning);

            DotnetPluginRegistry.Instance.RemoveAllPlugins();

            Engine.Shutdown();
            Engine = null;
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
