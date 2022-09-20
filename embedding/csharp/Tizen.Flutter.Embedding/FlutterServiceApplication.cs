// Copyright 2021 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

using System;
using System.Collections.Generic;
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
        /// Whether the app has started.
        /// </summary>
        public bool IsRunning => Engine != null;

        /// <summary>
        /// The Flutter engine instance.
        /// </summary>
        internal FlutterEngine Engine { get; private set; } = null;

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

        public FlutterDesktopPluginRegistrar GetRegistrarForPlugin(string pluginName)
        {
            if (IsRunning)
            {
                return Engine.GetRegistrarForPlugin(pluginName);
            }
            return new FlutterDesktopPluginRegistrar();
        }

        protected override void OnCreate()
        {
            base.OnCreate();

            Engine = new FlutterEngine(DartEntrypoint);
            if (!Engine.IsValid)
            {
                throw new Exception("Could not create a Flutter engine.");
            }

            if (!Engine.Run())
            {
                throw new Exception("Could not run a Flutter engine.");
            }
        }

        protected override void OnTerminate()
        {
            base.OnTerminate();

            Debug.Assert(IsRunning);

            DotnetPluginRegistry.Instance.RemoveAllPlugins();

            Engine.Shutdown();
            Engine = null;
        }

        protected override void OnAppControlReceived(AppControlReceivedEventArgs e)
        {
            Debug.Assert(IsRunning);

            Engine.NotifyAppControl(e.ReceivedAppControl);
        }

        protected override void OnLowMemory(LowMemoryEventArgs e)
        {
            base.OnLowMemory(e);

            Debug.Assert(IsRunning);

            Engine.NotifyLowMemoryWarning();
        }

        protected override void OnLocaleChanged(LocaleChangedEventArgs e)
        {
            base.OnLocaleChanged(e);

            Debug.Assert(IsRunning);

            Engine.NotifyLocaleChange();
        }

        protected override void OnRegionFormatChanged(RegionFormatChangedEventArgs e)
        {
            base.OnRegionFormatChanged(e);

            Debug.Assert(IsRunning);

            Engine.NotifyLocaleChange();
        }
    }
}
