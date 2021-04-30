// Copyright 2020 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using Tizen.Applications;
using static Tizen.Flutter.Embedding.Interop;

namespace Tizen.Flutter.Embedding
{
    /// <summary>
    /// The application base class which creates and manages the Flutter engine instance.
    /// </summary>
    public class FlutterApplication : CoreUIApplication, IPluginRegistry
    {
        protected const string LogTag = "ConsoleMessage";

        /// <summary>
        /// The switches to pass to the Flutter engine.
        /// Custom switches may be added before <see cref="OnCreate"/> is called.
        /// </summary>
        protected List<string> EngineArgs { get; } = new List<string>();

        /// <summary>
        /// The Flutter engine instance handle.
        /// </summary>
        protected FlutterWindowControllerHandle Handle { get; private set; } = new FlutterWindowControllerHandle();

        public override void Run(string[] args)
        {
            // Log any unhandled exception.
            AppDomain.CurrentDomain.UnhandledException += (s, e) =>
            {
                var exception = e.ExceptionObject as Exception;
                InternalLog.Error(LogTag, $"Unhandled exception: {exception}");
            };

            base.Run(args);
        }

        protected override void OnCreate()
        {
            base.OnCreate();

            // Get paths to resources required for launch.
            string resPath = Current.DirectoryInfo.Resource;
            string assetsPath = $"{resPath}/flutter_assets";
            string icuDataPath = $"{resPath}/icudtl.dat";
            string aotLibPath = $"{resPath}/../lib/libapp.so";

            // Read engine arguments passed from the tool.
            ParseEngineArgs();

            using var switches = new StringArray(EngineArgs);
            var engineProperties = new FlutterEngineProperties
            {
                assets_path = assetsPath,
                icu_data_path = icuDataPath,
                aot_library_path = aotLibPath,
                switches = switches.Handle,
                switches_count = (uint)switches.Length,
            };

            // This check is not actually required, but we want to make sure that libflutter_engine.so is loaded
            // before a call to FlutterCreateWindow() is made to avoid library loading issues on TV emulator.
            if (FlutterEngineRunsAOTCompiledDartCode())
            {
                InternalLog.Debug(LogTag, "Running in AOT mode.");
            }

            Handle = FlutterCreateWindow(ref engineProperties);
            if (Handle.IsInvalid)
            {
                throw new Exception("Could not launch a Flutter application.");
            }
        }

        private void ParseEngineArgs()
        {
            string appId = Current.ApplicationInfo.ApplicationId;
            string tempPath = $"/home/owner/share/tmp/sdk_tools/{appId}.rpm";
            if (!File.Exists(tempPath))
            {
                return;
            }
            try
            {
                var lines = File.ReadAllText(tempPath).Trim().Split("\n");
                foreach (string line in lines)
                {
                    InternalLog.Info(LogTag, $"Enabled: {line}");
                    EngineArgs.Add(line);
                }
                File.Delete(tempPath);
            }
            catch (Exception ex)
            {
                InternalLog.Warn(LogTag, $"Error while processing a file: {ex}");
            }
        }

        protected override void OnResume()
        {
            base.OnResume();

            Debug.Assert(Handle);

            FlutterNotifyAppIsResumed(Handle);
        }

        protected override void OnPause()
        {
            base.OnPause();

            Debug.Assert(Handle);

            FlutterNotifyAppIsPaused(Handle);
        }

        protected override void OnTerminate()
        {
            base.OnTerminate();

            Debug.Assert(Handle);

            FlutterDestroyWindow(Handle);
        }

        protected override void OnLowMemory(LowMemoryEventArgs e)
        {
            base.OnLowMemory(e);

            Debug.Assert(Handle);

            FlutterNotifyLowMemoryWarning(Handle);
        }

        protected override void OnLocaleChanged(LocaleChangedEventArgs e)
        {
            base.OnLocaleChanged(e);

            Debug.Assert(Handle);

            FlutterNotifyLocaleChange(Handle);
        }

        protected override void OnRegionFormatChanged(RegionFormatChangedEventArgs e)
        {
            base.OnRegionFormatChanged(e);

            Debug.Assert(Handle);

            FlutterNotifyLocaleChange(Handle);
        }

        /// <summary>
        /// Returns the plugin registrar handle for the plugin with the given name.
        /// The name must be unique across the application.
        /// </summary>
        public IntPtr GetRegistrarForPlugin(string pluginName)
        {
            if (Handle)
            {
                return FlutterDesktopGetPluginRegistrar(Handle, pluginName);
            }
            return IntPtr.Zero;
        }
    }
}
