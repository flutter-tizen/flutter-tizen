// Copyright 2020 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

using System;
using System.Runtime.InteropServices;

namespace Tizen.Flutter.Embedding
{
    internal static class Interop
    {
        [StructLayout(LayoutKind.Sequential)]
        public struct FlutterWindowProperties
        {
            public string title;
            public int x;
            public int y;
            public int width;
            public int height;
        }

        [StructLayout(LayoutKind.Sequential)]
        public struct FlutterEngineProperties
        {
            public string assets_path;
            public string icu_data_path;
            public string aot_library_path;
            public IntPtr switches;
            public uint switches_count;
        }

        public static string PlatformVersion = string.Empty;

        private static bool IsTizen40 => PlatformVersion.StartsWith("4.0");

        public static FlutterWindowControllerHandle FlutterCreateWindow(
            ref FlutterWindowProperties window_properties,
            ref FlutterEngineProperties engine_properties)
        {
            if (IsTizen40)
                return Tizen40Embedder.FlutterCreateWindow(ref window_properties, ref engine_properties);
            else
                return DefaultEmbedder.FlutterCreateWindow(ref window_properties, ref engine_properties);
        }

        public static void FlutterDestoryWindow(FlutterWindowControllerHandle window)
        {
            if (IsTizen40)
                Tizen40Embedder.FlutterDestoryWindow(window);
            else
                DefaultEmbedder.FlutterDestoryWindow(window);
        }

        public static void FlutterNotifyLocaleChange(FlutterWindowControllerHandle window)
        {
            if (IsTizen40)
                Tizen40Embedder.FlutterNotifyLocaleChange(window);
            else
                DefaultEmbedder.FlutterNotifyLocaleChange(window);
        }

        public static void FlutterNotifyLowMemoryWarning(FlutterWindowControllerHandle window)
        {
            if (IsTizen40)
                Tizen40Embedder.FlutterNotifyLowMemoryWarning(window);
            else
                DefaultEmbedder.FlutterNotifyLowMemoryWarning(window);
        }

        public static void FlutterNotifyAppIsResumed(FlutterWindowControllerHandle window)
        {
            if (IsTizen40)
                Tizen40Embedder.FlutterNotifyAppIsResumed(window);
            else
                DefaultEmbedder.FlutterNotifyAppIsResumed(window);
        }

        public static void FlutterNotifyAppIsPaused(FlutterWindowControllerHandle window)
        {
            if (IsTizen40)
                Tizen40Embedder.FlutterNotifyAppIsPaused(window);
            else
                DefaultEmbedder.FlutterNotifyAppIsPaused(window);
        }

        public static void FlutterRotateWindow(FlutterWindowControllerHandle window, int degree)
        {
            if (IsTizen40)
                Tizen40Embedder.FlutterRotateWindow(window, degree);
            else
                DefaultEmbedder.FlutterRotateWindow(window, degree);
        }

        public static IntPtr FlutterDesktopGetPluginRegistrar(
            FlutterWindowControllerHandle window, string plugin_name)
        {
            if (IsTizen40)
                return Tizen40Embedder.FlutterDesktopGetPluginRegistrar(window, plugin_name);
            else
                return DefaultEmbedder.FlutterDesktopGetPluginRegistrar(window, plugin_name);
        }

        #region Default
        private static class DefaultEmbedder
        {
            private const string SharedLibrary = "flutter_tizen.so";

            [DllImport(SharedLibrary)]
            public static extern FlutterWindowControllerHandle FlutterCreateWindow(
                ref FlutterWindowProperties window_properties,
                ref FlutterEngineProperties engine_properties);

            [DllImport(SharedLibrary)]
            public static extern void FlutterDestoryWindow(
                FlutterWindowControllerHandle window);

            [DllImport(SharedLibrary)]
            public static extern void FlutterNotifyLocaleChange(
                FlutterWindowControllerHandle window);

            [DllImport(SharedLibrary)]
            public static extern void FlutterNotifyLowMemoryWarning(
                FlutterWindowControllerHandle window);

            [DllImport(SharedLibrary)]
            public static extern void FlutterNotifyAppIsResumed(
                FlutterWindowControllerHandle window);

            [DllImport(SharedLibrary)]
            public static extern void FlutterNotifyAppIsPaused(
                FlutterWindowControllerHandle window);

            [DllImport(SharedLibrary)]
            public static extern void FlutterRotateWindow(
                FlutterWindowControllerHandle window, int degree);

            [DllImport(SharedLibrary)]
            public static extern IntPtr FlutterDesktopGetPluginRegistrar(
                FlutterWindowControllerHandle window, string plugin_name);
        }
        #endregion

        #region Tizen40
        private class Tizen40Embedder
        {
            private const string SharedLibrary = "flutter_tizen40.so";

            [DllImport(SharedLibrary)]
            public static extern FlutterWindowControllerHandle FlutterCreateWindow(
                ref FlutterWindowProperties window_properties,
                ref FlutterEngineProperties engine_properties);

            [DllImport(SharedLibrary)]
            public static extern void FlutterDestoryWindow(
                FlutterWindowControllerHandle window);

            [DllImport(SharedLibrary)]
            public static extern void FlutterNotifyLocaleChange(
                FlutterWindowControllerHandle window);

            [DllImport(SharedLibrary)]
            public static extern void FlutterNotifyLowMemoryWarning(
                FlutterWindowControllerHandle window);

            [DllImport(SharedLibrary)]
            public static extern void FlutterNotifyAppIsResumed(
                FlutterWindowControllerHandle window);

            [DllImport(SharedLibrary)]
            public static extern void FlutterNotifyAppIsPaused(
                FlutterWindowControllerHandle window);

            [DllImport(SharedLibrary)]
            public static extern void FlutterRotateWindow(
                FlutterWindowControllerHandle window, int degree);

            [DllImport(SharedLibrary)]
            public static extern IntPtr FlutterDesktopGetPluginRegistrar(
                FlutterWindowControllerHandle window, string plugin_name);
        }
        #endregion
    }
}
