// Copyright 2022 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Reflection;
using System.Runtime.InteropServices;
using Tizen.NUI;
using Tizen.NUI.BaseComponents;
using static Tizen.Flutter.Embedding.Interop;

namespace Tizen.Flutter.Embedding
{
    /// <summary>
    /// Displays a Flutter screen in a Tizen application.
    /// </summary>
    public class NUIFlutterView : ImageView
    {
        private uint _lastTouchEventTime = 0;
        private Size2D _size = new Size2D();

        /// <summary>
        /// The Flutter engine instance.
        /// </summary>
        public FlutterEngine Engine { get; set; } = null;

        /// <summary>
        /// The Flutter view instance handle.
        /// </summary>
        private FlutterDesktopView View { get; set; } = new FlutterDesktopView();

        /// <summary>
        /// Whether the view is running.
        /// </summary>
        public bool IsRunning => !View.IsInvalid;

        /// <summary>
        /// Starts running the view with the associated engine, creating if not set.
        /// </summary>
        /// <remarks>
        /// <see cref="Engine"/> must not be set again after this call.
        /// <see cref="Destroy"/> must be called if the view is no longer used.
        /// </remarks>
        public bool RunEngine()
        {
            if (IsRunning)
            {
                TizenLog.Error("The engine is already running.");
                return false;
            }

            Engine = Engine ?? new FlutterEngine();
            if (!Engine.IsValid)
            {
                TizenLog.Error("Could not create a Flutter engine.");
                return false;
            }

            Size2D size = GetDefaultSize();

            var nativeImageQueue =
                new NativeImageQueue((uint)size.Width, (uint)size.Height, NativeImageQueue.ColorFormat.RGBA8888);
            var nativeImageQueueRef = GetFieldValue<HandleRef>(nativeImageQueue, typeof(Tizen.NUI.Disposable), "swigCPtr");
            SetImage(nativeImageQueue.GenerateUrl().ToString());

            var imageViewRef = GetFieldValue<HandleRef>(this, typeof(Tizen.NUI.BaseHandle), "swigCPtr");

            var viewProperties = new FlutterDesktopViewProperties
            {
                width = size.Width,
                height = size.Height,
            };

            View = FlutterDesktopViewCreateFromImageView(
                ref viewProperties, Engine.Engine, imageViewRef.Handle, nativeImageQueueRef.Handle,
                Window.Instance.GetNativeId());
            if (View.IsInvalid)
            {
                TizenLog.Error("Could not launch a Flutter view.");
                return false;
            }

            _size = Size2D;

            RegisterEventHandlers();
            return true;
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

        private Size2D GetDefaultSize()
        {
            if (Size2D.Width == 0 || Size2D.Height == 0)
            {
                Container parent = GetParent();
                if (parent == null)
                {
                    Layer layer = Window.Instance.GetDefaultLayer();
                    return new Size2D(layer.Viewport.Width, layer.Viewport.Height);
                }
                else if (parent is View view)
                {
                    return view.Size2D;
                }
                else if (parent is Layer layer)
                {
                    return new Size2D(layer.Viewport.Width, layer.Viewport.Height);
                }
            }
            return Size2D;
        }

        private void RegisterEventHandlers()
        {
            Focusable = true;
            KeyEvent += (object s, KeyEventArgs e) =>
            {
                if (!IsRunning)
                {
                    return true;
                }

                FlutterDesktopViewOnKeyEvent(
                    View, e.Key.KeyPressedName, e.Key.KeyPressed, (uint)e.Key.KeyModifier, (uint)e.Key.KeyCode,
                    e.Key.State == Key.StateType.Down);
                return true;
            };

            TouchEvent += (object s, TouchEventArgs e) =>
            {
                if (!IsRunning)
                {
                    return true;
                }

                if (_lastTouchEventTime == e.Touch.GetTime())
                {
                    return false;
                }
                FocusManager.Instance.SetCurrentFocusView(this);

                FlutterDesktopPointerEventType type;
                switch (e.Touch.GetState(0))
                {
                    case PointStateType.Down:
                    default:
                        type = FlutterDesktopPointerEventType.kPointerDown;
                        break;
                    case PointStateType.Up:
                        type = FlutterDesktopPointerEventType.kPointerUp;
                        break;
                    case PointStateType.Motion:
                        type = FlutterDesktopPointerEventType.kPointerMove;
                        break;
                }
                FlutterDesktopViewOnPointerEvent(
                    View, type, e.Touch.GetLocalPosition(0).X, e.Touch.GetLocalPosition(0).Y, e.Touch.GetTime(),
                    e.Touch.GetDeviceId(0));

                _lastTouchEventTime = e.Touch.GetTime();
                return true;
            };

            Relayout += (object s, EventArgs e) =>
            {
                if (IsRunning && (_size.Width != Size2D.Width || _size.Height != Size2D.Height))
                {
                    FlutterDesktopViewResize(View, Size2D.Width, Size2D.Height);
                    _size = Size2D;
                }
            };
        }

        private T GetFieldValue<T>(object obj, Type type, string fieldName)
        {
            FieldInfo field = type.GetField(fieldName, BindingFlags.NonPublic | BindingFlags.Instance);
            return (T)field.GetValue(obj);
        }
    }
}
