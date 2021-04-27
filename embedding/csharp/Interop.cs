// Copyright 2020 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

using System;
using System.Runtime.InteropServices;

namespace Tizen.Flutter.Embedding
{
    internal static class Interop
    {
        [DllImport("flutter_engine.so")]
        public static extern bool FlutterEngineRunsAOTCompiledDartCode();

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

        [DllImport("flutter_tizen.so")]
        public static extern FlutterWindowControllerHandle FlutterCreateWindow(
            ref FlutterWindowProperties window_properties,
            ref FlutterEngineProperties engine_properties);

        [DllImport("flutter_tizen.so")]
        public static extern void FlutterDestroyWindow(
            FlutterWindowControllerHandle window);

        [DllImport("flutter_tizen.so")]
        public static extern void FlutterNotifyLocaleChange(
            FlutterWindowControllerHandle window);

        [DllImport("flutter_tizen.so")]
        public static extern void FlutterNotifyLowMemoryWarning(
            FlutterWindowControllerHandle window);

        [DllImport("flutter_tizen.so")]
        public static extern void FlutterNotifyAppIsResumed(
            FlutterWindowControllerHandle window);

        [DllImport("flutter_tizen.so")]
        public static extern void FlutterNotifyAppIsPaused(
            FlutterWindowControllerHandle window);

        [DllImport("flutter_tizen.so")]
        public static extern IntPtr FlutterDesktopGetPluginRegistrar(
            FlutterWindowControllerHandle window, string plugin_name);
    }
}
