// Copyright 2020 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

using System;
using System.Collections.Generic;
using System.Linq;
using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;
using System.Text.RegularExpressions;
using Tizen.Applications;
using Tizen.System;
using static Tizen.Flutter.Embedding.Interop;

namespace Tizen.Flutter.Embedding
{
    /// <summary>
    /// The application base class which creates and manages the Flutter engine instance.
    /// </summary>
    public class FlutterApplication : CoreUIApplication
    {
        protected const string LogTag = "ConsoleMessage";

        /// <summary>
        /// The switches to pass to the Flutter engine.
        /// Any element can be added before <see cref="OnCreate"/> is called.
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

            // Parse engine arguments passed from the tool. This should be reworked.
            for (int i = args.Length - 1; i >= 0; i--)
            {
                if (args[i].StartsWith("FLUTTER_ENGINE_ARGS"))
                {
                    args[i] = args[i].Substring(args[i].IndexOf(' ')).Trim();
                    InternalLog.Debug(LogTag, "Run with: " + args[i]);

                    // A regex is used here to correctly parse "quoted" strings.
                    // TODO: Avoid using Linq to reduce the memory pressure.
                    EngineArgs.AddRange(Regex.Matches(args[i], @"[\""].+?[\""]|[^ ]+")
                        .Cast<Match>()
                        .Select(x => x.Value.Trim('"')));
                    break;
                }
            }

            base.Run(args);
        }

        protected override void OnCreate()
        {
            base.OnCreate();

            // Get the screen size of the currently running device.
            if (!Information.TryGetValue("http://tizen.org/feature/screen.width", out int width) ||
                !Information.TryGetValue("http://tizen.org/feature/screen.height", out int height))
            {
                InternalLog.Error(LogTag, "Could not obtain the screen size.");
                return;
            }
            var windowProperties = new FlutterWindowProperties
            {
                width = width,
                height = height
            };

            // Get paths to resources required for launch.
            string resPath = Current.DirectoryInfo.Resource;
            string assetsPath = $"{resPath}/flutter_assets";
            string icuDataPath = $"{resPath}/icudtl.dat";
            string arch = RuntimeInformation.ProcessArchitecture switch
            {
                Architecture.X86 => "x86",
                Architecture.X64 => "x64",
                Architecture.Arm => "arm",
                Architecture.Arm64 => "aarch64",
                _ => "",
            };
            string aotLibPath = $"{resPath}/../lib/{arch}/libapp.so";

            using var switches = new StringArray(EngineArgs);
            var engineProperties = new FlutterEngineProperties
            {
                assets_path = assetsPath,
                icu_data_path = icuDataPath,
                aot_library_path = aotLibPath,
                switches = switches.Handle,
                switches_count = (uint)switches.Length,
            };

            Handle = FlutterCreateWindow(ref Unsafe.AsRef(windowProperties), ref Unsafe.AsRef(engineProperties));
            if (Handle.IsInvalid)
            {
                throw new Exception("Could not launch a Flutter application.");
            }
        }

        protected override void OnResume()
        {
            base.OnResume();

            if (!Handle.IsInvalid)
            {
                FlutterNotifyAppIsResumed(Handle);
            }
        }

        protected override void OnPause()
        {
            base.OnPause();

            if (!Handle.IsInvalid)
            {
                FlutterNotifyAppIsPaused(Handle);
            }
        }

        protected override void OnTerminate()
        {
            base.OnTerminate();

            if (!Handle.IsInvalid)
            {
                FlutterDestoryWindow(Handle);
            }
        }

        protected override void OnDeviceOrientationChanged(DeviceOrientationEventArgs e)
        {
            base.OnDeviceOrientationChanged(e);

            if (!Handle.IsInvalid)
            {
                FlutterRotateWindow(Handle, (int)e.DeviceOrientation);
            }
        }

        protected override void OnLocaleChanged(LocaleChangedEventArgs e)
        {
            base.OnLocaleChanged(e);

            if (!Handle.IsInvalid)
            {
                FlutterNotifyLocaleChange(Handle);
            }
        }

        protected override void OnRegionFormatChanged(RegionFormatChangedEventArgs e)
        {
            base.OnRegionFormatChanged(e);

            if (!Handle.IsInvalid)
            {
                FlutterNotifyLocaleChange(Handle);
            }
        }

        protected override void OnLowMemory(LowMemoryEventArgs e)
        {
            base.OnLowMemory(e);

            if (!Handle.IsInvalid)
            {
                FlutterNotifyLowMemoryWarning(Handle);
            }
        }

        public IntPtr GetPluginRegistrar(string pluginName)
        {
            if (!Handle.IsInvalid)
            {
                return FlutterDesktopGetPluginRegistrar(Handle, pluginName);
            }
            return IntPtr.Zero;
        }
    }
}
