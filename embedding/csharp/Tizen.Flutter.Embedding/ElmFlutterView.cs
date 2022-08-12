// Copyright 2022 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

using System;
using System.Diagnostics;
using ElmSharp;
using static Tizen.Flutter.Embedding.Interop;

namespace Tizen.Flutter.Embedding
{
    /// <summary>
    /// Represents an <see cref="EvasObject"/> instance created by the embedder.
    /// </summary>
    class EvasObjectImpl : EvasObject
    {
        public EvasObjectImpl(EvasObject parent, IntPtr handle) : base(parent)
        {
            Handle = handle;
        }

        protected override IntPtr CreateHandle(EvasObject parent)
        {
            return Handle;
        }
    }

    /// <summary>
    /// Displays a Flutter screen in a Tizen application.
    /// </summary>
    public class ElmFlutterView
    {
        /// <summary>
        /// The Flutter engine instance.
        /// </summary>
        public FlutterEngine Engine { get; set; } = null;

        /// <summary>
        /// The Flutter view instance handle.
        /// </summary>
        private FlutterDesktopView View { get; set; } = new FlutterDesktopView();

        /// <summary>
        /// The backing Evas object for this view.
        /// </summary>
        public EvasObject EvasObject { get; private set; } = null;

        /// <summary>
        /// The parent of <see cref="EvasObject"/>.
        /// </summary>
        private EvasObject Parent { get; set; } = null;

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

                return EvasObject.Geometry.Width;
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

                return EvasObject.Geometry.Height;
            }
        }

        public ElmFlutterView(EvasObject parent)
        {
            Parent = parent;
        }

        public ElmFlutterView(EvasObject parent, int initialWidth, int initialHeight)
        {
            Parent = parent;
            InitialWidth = initialWidth;
            InitialHeight = initialHeight;
        }

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

            if (Parent == null)
            {
                TizenLog.Error("The parent object is invalid.");
                return false;
            }

            if (Engine == null)
            {
                Engine = new FlutterEngine();
            }

            if (!Engine.IsValid)
            {
                TizenLog.Error("Could not create a Flutter engine.");
                return false;
            }

            var viewProperties = new FlutterDesktopViewProperties
            {
                width = InitialWidth,
                height = InitialHeight,
            };

            View = FlutterDesktopViewCreateFromElmParent(ref viewProperties, Engine.Engine, Parent);
            if (View.IsInvalid)
            {
                TizenLog.Error("Could not launch a Flutter view.");
                return false;
            }

            EvasObject = new EvasObjectImpl(Parent, FlutterDesktopViewGetEvasObject(View));
            if (!EvasObject.IsRealized)
            {
                TizenLog.Error("Could not get an Evas object.");
                return false;
            }

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

        /// <summary>
        /// Resizes the view.
        /// </summary>
        public void Resize(int width, int height)
        {
            Debug.Assert(IsRunning);

            if (EvasObject.Geometry.Width != width || EvasObject.Geometry.Height != height)
            {
                FlutterDesktopViewResize(View, width, height);
            }
        }
    }
}
