// Copyright 2022 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

using System;
using System.Collections.Generic;
using System.IO;
using Tizen.Applications;
using static Tizen.Flutter.Embedding.Interop;

namespace Tizen.Flutter.Embedding
{
    /// <summary>
    /// The engine for Flutter execution.
    /// </summary>
    public class FlutterEngine : IPluginRegistry
    {
        /// <summary>
        /// Handle for interacting with the C API's engine reference.
        /// </summary>
        protected internal FlutterDesktopEngine Engine { get; private set; } = new FlutterDesktopEngine();

        /// <summary>
        /// Whether the engine is valid or not.
        /// </summary>
        public bool IsValid => !Engine.IsInvalid;

        public FlutterEngine(string dartEntrypoint, List<string> dartEntrypointArgs) : this(
            "../res/flutter_assets", "../res/icudtl.dat", "../lib/libapp.so", dartEntrypoint, dartEntrypointArgs)
        {
        }

        public FlutterEngine(string assetsPath, string icuDataPath, string aotLibraryPath,
            string dartEntrypoint, List<string> dartEntrypointArgs)
        {
            using (var switches = new StringArray(ParseEngineArgs()))
            using (var entrypointArgs = new StringArray(dartEntrypointArgs))
            {
                var engineProperties = new FlutterDesktopEngineProperties
                {
                    assets_path = assetsPath,
                    icu_data_path = icuDataPath,
                    aot_library_path = aotLibraryPath,
                    switches = switches.Handle,
                    switches_count = (uint)switches.Length,
                    entrypoint = dartEntrypoint,
                    dart_entrypoint_argc = entrypointArgs.Length,
                    dart_entrypoint_argv = entrypointArgs.Handle,
                };

                Engine = FlutterDesktopEngineCreate(ref engineProperties);
            }
        }

        /// <summary>
        /// Starts running the engine.
        /// </summary>
        public bool Run()
        {
            if (IsValid)
            {
                return FlutterDesktopEngineRun(Engine);
            }
            return false;
        }

        /// <summary>
        /// Terminates the running engine.
        /// </summary>
        public void Shutdown()
        {
            if (IsValid)
            {
                FlutterDesktopEngineShutdown(Engine);
                Engine = new FlutterDesktopEngine();
            }
        }

        /// <summary>
        /// Notifies that the host app is visible and responding to user input.
        /// This method notifies the running Flutter app that it is "resumed" as per the Flutter app lifecycle.
        /// </summary>
        public void NotifyAppIsResumed()
        {
            if (IsValid)
            {
                FlutterDesktopEngineNotifyAppIsResumed(Engine);
            }
        }

        /// <summary>
        /// Notifies that the host app is invisible and not responding to user input.
        /// This method notifies the running Flutter app that it is "inactive" as per the Flutter app lifecycle.
        /// </summary>
        public void NotifyAppIsPaused()
        {
            if (IsValid)
            {
                FlutterDesktopEngineNotifyAppIsPaused(Engine);
            }
        }

        /// <summary>
        /// Notifies that the host app received an app control.
        /// This method notifies the running Flutter app that it is "paused" as per the Flutter app lifecycle.
        /// </summary>
        public void NotifyAppControl(ReceivedAppControl appControl)
        {
            if (IsValid)
            {
                FlutterDesktopEngineNotifyAppControl(Engine, appControl.SafeAppControlHandle);
            }
        }

        /// <summary>
        /// Notifies that a low memory warning has been received.
        /// This method sends a "memory pressure warning" message to Flutter over the "system channel".
        /// </summary>
        public void NotifyLowMemoryWarning()
        {
            if (IsValid)
            {
                FlutterDesktopEngineNotifyLowMemoryWarning(Engine);
            }
        }

        /// <summary>
        /// Notifies that the locale has changed.
        /// ThisThis method sends a "locale change" message to Flutter.
        /// </summary>
        public void NotifyLocaleChange()
        {
            if (IsValid)
            {
                FlutterDesktopEngineNotifyLocaleChange(Engine);
            }
        }

        public FlutterDesktopPluginRegistrar GetRegistrarForPlugin(string pluginName)
        {
            if (IsValid)
            {
                return FlutterDesktopEngineGetPluginRegistrar(Engine, pluginName);
            }
            return new FlutterDesktopPluginRegistrar();
        }

        public FlutterDesktopMessenger GetMessenger()
        {
            if (IsValid)
            {
                return FlutterDesktopEngineGetMessenger(Engine);
            }
            return new FlutterDesktopMessenger();
        }

        /// <summary>
        /// Reads engine arguments passed from the flutter-tizen tool.
        /// </summary>
        private static IList<string> ParseEngineArgs()
        {
            var result = new List<string>();

            string appId = Application.Current.ApplicationInfo.ApplicationId;
            string tempPath = $"/home/owner/share/tmp/sdk_tools/{appId}.rpm";
            if (!File.Exists(tempPath))
            {
                return result;
            }

            try
            {
                var lines = File.ReadAllText(tempPath).Trim().Split('\n');
                foreach (string line in lines)
                {
                    TizenLog.Info($"Enabled: {line}");
                    result.Add(line);
                }
                File.Delete(tempPath);
            }
            catch (Exception ex)
            {
                TizenLog.Warn($"Error while processing a file: {ex}");
            }

            return result;
        }
    }
}
