// Copyright 2022 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

using System.Collections.Generic;
using Tizen.Applications;
using static Tizen.Flutter.Embedding.Interop;

namespace Tizen.Flutter.Embedding
{
    /// <summary>
    /// Enumeration for the thread policy of the Flutter engine's UI isolate.
    /// </summary>
    public enum FlutterUIThreadPolicy
    {
        /// <summary>
        /// Currently runs the UI isolate on the platform thread. Equivalent to <see cref="RunOnPlatformThread"/>.
        /// </summary>
        Default,
        /// <summary>
        /// Runs the UI isolate on the platform thread.
        /// </summary>
        RunOnPlatformThread,
        /// <summary>
        /// Runs the UI isolate on a separate thread.
        /// </summary>
        RunOnSeparateThread,
    }

    /// <summary>
    /// The engine for Flutter execution.
    /// </summary>
    public class FlutterEngine : IPluginRegistry
    {
        private readonly FlutterEngineArguments _engineArguments;

        /// <summary>
        /// Creates a <see cref="FlutterEngine"/> with an optional entrypoint name and entrypoint arguments.
        /// </summary>
        /// <param name="dartEntrypoint">The optional entrypoint in the Dart project. Defaults to main() if empty.</param>
        /// <param name="dartEntrypointArgs">The optional entrypoint arguments.</param>
        /// <param name="uiThreadPolicy">
        /// The thread policy for running the UI isolate. Defaults to <see cref="FlutterUIThreadPolicy.Default"/>,
        /// which merges the UI isolate onto the platform thread. If the UI isolate is blocked by a long-running
        /// synchronous native call (e.g. via FFI), the platform thread can no longer respond to the Tizen app
        /// framework (app control/resume requests), which may cause the app to be killed by the platform watchdog.
        ///
        /// <see cref="FlutterUIThreadPolicy.RunOnSeparateThread"/> is available for apps that need it, but apps
        /// must still make sure their Dart code never blocks indefinitely, whichever policy is used. Apps that
        /// choose this policy are responsible for any issues that result from doing so.
        /// </param>
        public FlutterEngine(
            string dartEntrypoint = "", List<string> dartEntrypointArgs = null,
            FlutterUIThreadPolicy uiThreadPolicy = FlutterUIThreadPolicy.Default)
            : this("../res/flutter_assets", "../res/icudtl.dat", "../lib/libapp.so", dartEntrypoint,
                  dartEntrypointArgs, uiThreadPolicy)
        {
        }

        /// <summary>
        /// Creates a <see cref="FlutterEngine"/> with the given arguments.
        /// </summary>
        /// <remarks>See the other constructor for the meaning of <paramref name="uiThreadPolicy"/>.</remarks>
        public FlutterEngine(
            string assetsPath, string icuDataPath, string aotLibraryPath, string dartEntrypoint = "",
            List<string> dartEntrypointArgs = null,
            FlutterUIThreadPolicy uiThreadPolicy = FlutterUIThreadPolicy.Default)
        {
            dartEntrypointArgs = dartEntrypointArgs ?? new List<string>();
            _engineArguments = new FlutterEngineArguments();

            using (var switches = new StringArray(_engineArguments.Arguments))
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
                    ui_thread_policy = (FlutterDesktopUIThreadPolicy)uiThreadPolicy,
                };

                Engine = FlutterDesktopEngineCreate(ref engineProperties);
            }
        }

        /// <summary>
        /// Whether the engine is valid or not.
        /// </summary>
        public bool IsValid => !Engine.IsInvalid;

        /// <summary>
        /// The engine arguments instance containing parsed arguments and metadata flags.
        /// </summary>
        public FlutterEngineArguments Arguments => _engineArguments;

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
        /// Notifies that the engine is detached from any host views.
        /// This method notifies the running Flutter app that it is "detached" as per the Flutter app lifecycle.
        /// </summary>
        public void NotifyAppIsDetached()
        {
            if (IsValid)
            {
                FlutterDesktopEngineNotifyAppIsDetached(Engine);
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

    }
}
