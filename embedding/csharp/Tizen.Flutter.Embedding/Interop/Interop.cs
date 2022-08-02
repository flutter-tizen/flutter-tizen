// Copyright 2020 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

using System;
using System.Runtime.InteropServices;
using Tizen.Applications;

namespace Tizen.Flutter.Embedding
{
    public static class Interop
    {
        #region flutter_tizen.h
        public enum FlutterDesktopRendererType
        {
            kEvasGL,
            kEGL,
        };

        [StructLayout(LayoutKind.Sequential)]
        public struct FlutterDesktopWindowProperties
        {
            public int x;
            public int y;
            public int width;
            public int height;
            [MarshalAs(UnmanagedType.U1)]
            public bool transparent;
            [MarshalAs(UnmanagedType.U1)]
            public bool focusable;
            [MarshalAs(UnmanagedType.U1)]
            public bool top_level;
            public FlutterDesktopRendererType renderer_type;
        }

        [StructLayout(LayoutKind.Sequential)]
        public struct FlutterDesktopEngineProperties
        {
            public string assets_path;
            public string icu_data_path;
            public string aot_library_path;
            public IntPtr switches;
            public uint switches_count;
            public string entrypoint;
            public int dart_entrypoint_argc;
            public IntPtr dart_entrypoint_argv;
        }

        [DllImport("flutter_tizen.so")]
        public static extern FlutterDesktopEngine FlutterDesktopEngineCreate(
            ref FlutterDesktopEngineProperties engine_properties);

        [DllImport("flutter_tizen.so")]
        public static extern bool FlutterDesktopEngineRun(
            FlutterDesktopEngine engine);

        [DllImport("flutter_tizen.so")]
        public static extern void FlutterDesktopEngineShutdown(
            FlutterDesktopEngine engine);

        [DllImport("flutter_tizen.so")]
        public static extern FlutterDesktopPluginRegistrar FlutterDesktopEngineGetPluginRegistrar(
            FlutterDesktopEngine engine,
            string plugin_name);

        [DllImport("flutter_tizen.so")]
        public static extern FlutterDesktopMessenger FlutterDesktopEngineGetMessenger(
            FlutterDesktopEngine engine);

        [DllImport("flutter_tizen.so")]
        public static extern IntPtr FlutterDesktopPluginRegistrarGetNativeWindow(
            FlutterDesktopPluginRegistrar registrar);

        [DllImport("flutter_tizen.so")]
        public static extern void FlutterDesktopEngineNotifyAppControl(
            FlutterDesktopEngine engine,
            SafeAppControlHandle handle);

        [DllImport("flutter_tizen.so")]
        public static extern void FlutterDesktopEngineNotifyLocaleChange(
            FlutterDesktopEngine engine);

        [DllImport("flutter_tizen.so")]
        public static extern void FlutterDesktopEngineNotifyLowMemoryWarning(
            FlutterDesktopEngine engine);

        [DllImport("flutter_tizen.so")]
        public static extern void FlutterDesktopEngineNotifyAppIsResumed(
            FlutterDesktopEngine engine);

        [DllImport("flutter_tizen.so")]
        public static extern void FlutterDesktopEngineNotifyAppIsPaused(
            FlutterDesktopEngine engine);

        [DllImport("flutter_tizen.so")]
        public static extern FlutterDesktopView FlutterDesktopViewCreateFromNewWindow(
            ref FlutterDesktopWindowProperties window_properties,
            FlutterDesktopEngine engine);

        [DllImport("flutter_tizen.so")]
        public static extern void FlutterDesktopViewDestroy(
            FlutterDesktopView view);
        #endregion

        #region flutter_messenger.h
        [UnmanagedFunctionPointer(CallingConvention.Cdecl)]
        public delegate void FlutterDesktopBinaryReply(
            IntPtr data,
            uint data_size,
            IntPtr user_data);

        [StructLayout(LayoutKind.Sequential)]
        public struct FlutterDesktopMessage
        {
            public uint struct_size;
            public string channel;
            public IntPtr message;
            public uint message_size;
            public IntPtr response_handle;
        }

        [UnmanagedFunctionPointer(CallingConvention.Cdecl)]
        public delegate void FlutterDesktopMessageCallback(
            [MarshalAs(
                UnmanagedType.CustomMarshaler,
                MarshalTypeRef = typeof(FlutterDesktopMessenger.Marshaler))]
            FlutterDesktopMessenger messenger,
            IntPtr message,
            IntPtr user_data);

        [DllImport("flutter_tizen.so")]
        public static extern bool FlutterDesktopMessengerSend(
            FlutterDesktopMessenger messenger,
            string channel,
            IntPtr message,
            uint message_size);

        [DllImport("flutter_tizen.so")]
        public static extern bool FlutterDesktopMessengerSendWithReply(
            FlutterDesktopMessenger messenger,
            string channel,
            IntPtr message,
            uint message_size,
            FlutterDesktopBinaryReply reply,
            IntPtr user_data);

        [DllImport("flutter_tizen.so")]
        public static extern void FlutterDesktopMessengerSendResponse(
            FlutterDesktopMessenger messenger,
            IntPtr handle,
            IntPtr data,
            uint data_length);

        [DllImport("flutter_tizen.so")]
        public static extern void FlutterDesktopMessengerSetCallback(
            FlutterDesktopMessenger messenger,
            string channel,
            FlutterDesktopMessageCallback callback,
            IntPtr user_data);
        #endregion

        #region flutter_plugin_registrar.h
        [DllImport("flutter_tizen.so")]
        public static extern FlutterDesktopMessenger FlutterDesktopPluginRegistrarGetMessenger(
            FlutterDesktopPluginRegistrar registrar);
        #endregion
    }
}
