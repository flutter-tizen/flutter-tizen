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
        private const string MetadataKeyEnableImepeller = "http://tizen.org/metadata/flutter_tizen/enable_impeller";

        /// <summary>
        /// Creates a <see cref="FlutterEngine"/> with an optional entrypoint name and entrypoint arguments.
        /// </summary>
        public FlutterEngine(string dartEntrypoint = "", List<string> dartEntrypointArgs = null)
            : this("../res/flutter_assets", "../res/icudtl.dat", "../lib/libapp.so", dartEntrypoint, dartEntrypointArgs)
        {
        }

        /// <summary>
        /// Creates a <see cref="FlutterEngine"/> with the given arguments.
        /// </summary>
        public FlutterEngine(
            string assetsPath, string icuDataPath, string aotLibraryPath, string dartEntrypoint = "",
            List<string> dartEntrypointArgs = null)
        {
            dartEntrypointArgs = dartEntrypointArgs ?? new List<string>();

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
        /// Whether the engine is valid or not.
        /// </summary>
        public bool IsValid => !Engine.IsInvalid;

        /// <summary>
        /// Whether the impeller is enabled or not.
        /// </summary>
        public bool IsImpellerEnabled { get; private set; } = false;

        /// <summary>
        /// Handle for interacting with the C API's engine reference.
        /// </summary>
        protected internal FlutterDesktopEngine Engine { get; private set; } = new FlutterDesktopEngine();

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
        /// This method sends a "memory pressure warning" message to Flutter over the "system" channel.
        /// </summary>
        public void NotifyLowMemoryWarning()
        {
            if (IsValid)
            {
                FlutterDesktopEngineNotifyLowMemoryWarning(Engine);
            }
        }

        /// <summary>
        /// Notifies that the system locale has changed.
        /// This method sends a "locale change" message to Flutter.
        /// </summary>
        public void NotifyLocaleChange()
        {
            if (IsValid)
            {
                FlutterDesktopEngineNotifyLocaleChange(Engine);
            }
        }

        /// <InheritDoc/>
        public FlutterDesktopPluginRegistrar GetRegistrarForPlugin(string pluginName)
        {
            if (IsValid)
            {
                return FlutterDesktopEngineGetPluginRegistrar(Engine, pluginName);
            }
            return new FlutterDesktopPluginRegistrar();
        }

        /// <summary>
        /// Returns the messenger associated with the engine.
        /// </summary>
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
        private IList<string> ParseEngineArgs()
        {
            var result = new List<string>();
            var appInfo = Application.Current.ApplicationInfo;

            string appId = appInfo.ApplicationId;
            bool enableImpellerKeyExist = appInfo.Metadata.ContainsKey(MetadataKeyEnableImepeller);
            string tempPath = $"/home/owner/share/tmp/sdk_tools/{appId}.rpm";

            if (File.Exists(tempPath))
            {
                try
                {
                    var lines = File.ReadAllText(tempPath).Trim().Split('\n');
                    foreach (string line in lines)
                    {
                        result.Add(line);
                    }
                    File.Delete(tempPath);
                }
                catch (Exception ex)
                {
                    TizenLog.Warn($"Error while processing a file: {ex}");
                }
            }

            if (enableImpellerKeyExist)
            {
                if (!result.Contains("--enable-impeller") && appInfo.Metadata[MetadataKeyEnableImepeller] == "true")
                {
                    IsImpellerEnabled = true;
                    result.Insert(0, "--enable-impeller");
                }
                else if (result.Contains("--enable-impeller") && appInfo.Metadata[MetadataKeyEnableImepeller] == "false")
                {
                    result.Remove("--enable-impeller");
                }
            }

            foreach (string flag in result)
            {
                TizenLog.Info($"Enabled: {flag}");
            }
            return result;
        }
    }
}
