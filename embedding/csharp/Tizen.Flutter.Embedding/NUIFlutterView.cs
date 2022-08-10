﻿// Copyright 2022 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Reflection;
using Tizen.NUI;
using Tizen.NUI.BaseComponents;

using static Tizen.Flutter.Embedding.Interop;

namespace Tizen.Flutter.Embedding
{
    /// <summary>
    /// Displays a Flutter screen in a Tizen application.
    /// </summary>
    public class NUIFlutterView : ImageView, IPluginRegistry
    {
        /// <summary>
        /// The Flutter engine instance.
        /// </summary>
        private FlutterEngine Engine { get; set; } = null;

        /// <summary>
        /// The Flutter view instance handle.
        /// </summary>
        private FlutterDesktopView View { get; set; } = new FlutterDesktopView();

        /// <summary>
        /// The initial width of the view. Defaults to the parent width if the value is zero.
        /// </summary>
        private int InitialWidth { get; set; } = 0;

        /// <summary>
        /// The initial height of the view. Defaults to the parent height if the value is zero.
        /// </summary>
        private int InitialHeight { get; set; } = 0;

        /// <summary>
        /// Whether the view is running.
        /// </summary>
        public bool IsRunning => !View.IsInvalid;

        /// <summary>
        /// The current width of the view.
        /// </summary>
        public int Width
        {
            get
            {
                Debug.Assert(IsRunning);

                return base.Size2D.Width;
            }
        }

        /// <summary>
        /// The current height of the view.
        /// </summary>
        public int Height
        {
            get
            {
                Debug.Assert(IsRunning);

                return base.Size2D.Height;
            }
        }

        /// <summary>
        /// Starts running the view with the associated engine, creating if not set.
        /// </summary>
        public bool RunEngine()
        {
            if (Engine == null)
            {
                Engine = new FlutterEngine();
            }

            if (!Engine.IsValid)
            {
                throw new Exception("Could not create a Flutter engine.");
            }

            Type baseType = typeof(NativeImageQueue).BaseType.BaseType.BaseType;
            FieldInfo field = baseType.GetField("swigCPtr", global::System.Reflection.BindingFlags.NonPublic | global::System.Reflection.BindingFlags.Instance);
            var nativeImageQueue = new NativeImageQueue((uint)base.Size2D.Width, (uint)base.Size2D.Height, NativeImageQueue.ColorFormat.RGBA8888);
            global::System.Runtime.InteropServices.HandleRef nativeImageQueueHandle = (global::System.Runtime.InteropServices.HandleRef)field?.GetValue(nativeImageQueue);
            base.SetImage(nativeImageQueue.GenerateUrl().ToString());

            var viewProperties = new FlutterDesktopViewProperties
            {
                width = base.Size2D.Width,
                height = base.Size2D.Height,
            };

            View = FlutterDesktopViewCreateFromNativeImageQueue(ref viewProperties, Engine.Engine, nativeImageQueueHandle.Handle);
            if (View.IsInvalid)
            {
                TizenLog.Error("Could not launch a Flutter view.");
                return false;
            }

            base.Focusable = true;
            base.KeyEvent += (object source, View.KeyEventArgs eventArgs) =>
            {
                FlutterDesktopViewOnKeyEvent(View, eventArgs.Key.LogicalKey, eventArgs.Key.KeyString, (uint)eventArgs.Key.KeyModifier, (uint)eventArgs.Key.KeyCode, eventArgs.Key.State == Key.StateType.Down ? true : false);
                return true;
            };

            base.TouchEvent += (object source, View.TouchEventArgs eventArgs) =>
            {
                FocusManager.Instance.SetCurrentFocusView(this);
                FlutterDesktopViewMouseEventType type;
                switch (eventArgs.Touch.GetState(0))
                {
                    case PointStateType.Down:
                    default:
                        type = FlutterDesktopViewMouseEventType.kMouseDown;
                        break;
                    case PointStateType.Up:
                        type = FlutterDesktopViewMouseEventType.kMouseUp;
                        break;
                    case PointStateType.Motion:
                        type = FlutterDesktopViewMouseEventType.kMouseMove;
                        break;
                }
                FlutterDesktopViewOnMouseEvent(View, type, eventArgs.Touch.GetLocalPosition(0).X, eventArgs.Touch.GetLocalPosition(0).Y, eventArgs.Touch.GetTime(), eventArgs.Touch.GetDeviceId(0));
                return true;
            };
            return true;
        }

        /// <summary>
        /// Sets an engine associated with this view.
        /// </summary>
        public void SetEngine(FlutterEngine engine)
        {
            Engine = engine;
        }

        /// <summary>
        /// Terminates the running view and the associated engine.
        /// </summary>
        public void Destroy()
        {
            if (IsRunning)
            {
                FlutterDesktopViewDestroy(View);
                Engine = null;
                View = new FlutterDesktopView();
            }
        }

        /// <summary>
        /// Resizes the view.
        /// </summary>
        public void Resize(int width, int height)
        {
            Debug.Assert(IsRunning);

            if (base.Size2D.Width != width || base.Size2D.Height != height)
            {
                FlutterDesktopViewResize(View, width, height);
            }
        }

        public FlutterDesktopPluginRegistrar GetRegistrarForPlugin(string pluginName)
        {
            if (IsRunning)
            {
                return Engine.GetRegistrarForPlugin(pluginName);
            }
            return new FlutterDesktopPluginRegistrar();
        }
    }
}
