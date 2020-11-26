// Copyright 2020 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

using System;
using System.Runtime.InteropServices;

namespace Tizen.Flutter.Embedding
{
    internal static class Interop
    {
        #region flutter_tizen.h
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

        [DllImport("flutter.so")]
        public static extern FlutterWindowControllerHandle FlutterCreateWindow(
            [In] ref FlutterWindowProperties window_properties,
            [In] ref FlutterEngineProperties engine_properties);

        [DllImport("flutter.so")]
        public static extern void FlutterDestoryWindow(
            [In] FlutterWindowControllerHandle window);

        [DllImport("flutter.so")]
        public static extern void FlutterNotifyLocaleChange(
            [In] FlutterWindowControllerHandle window);

        [DllImport("flutter.so")]
        public static extern void FlutterNotifyLowMemoryWarning(
            [In] FlutterWindowControllerHandle window);

        [DllImport("flutter.so")]
        public static extern void FlutterNotifyAppIsResumed(
            [In] FlutterWindowControllerHandle window);

        [DllImport("flutter.so")]
        public static extern void FlutterNotifyAppIsPaused(
            [In] FlutterWindowControllerHandle window);

        [DllImport("flutter.so")]
        public static extern void FlutterRotateWindow(
            [In] FlutterWindowControllerHandle window,
            [In] int degree);

        [DllImport("flutter.so")]
        public static extern IntPtr FlutterDesktopGetPluginRegistrar(
            [In] FlutterWindowControllerHandle window,
            [In] string plugin_name);
        #endregion
    }
}
