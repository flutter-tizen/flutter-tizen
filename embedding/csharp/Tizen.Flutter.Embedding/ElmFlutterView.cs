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
            if (Handle == IntPtr.Zero)
            {
                throw new InvalidOperationException("The handle cannot be created again.");
            }
            return Handle;
        }
    }

    /// <summary>
    /// Displays a Flutter screen in a Tizen application.
    /// </summary>
    public class ElmFlutterView : IPluginRegistry
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

        public bool RunEngine()
        {
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
                throw new Exception("Could not create a Flutter engine.");
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

        public void SetEngine(FlutterEngine engine)
        {
            Engine = engine;
        }

        public void Destroy()
        {
            if (IsRunning)
            {
                FlutterDesktopViewDestroy(View);
                View = new FlutterDesktopView();
            }
        }

        public void Resize(int width, int height)
        {
            Debug.Assert(IsRunning);

            if (EvasObject.Geometry.Width != width || EvasObject.Geometry.Height != height)
            {
                FlutterDesktopViewResize(View, width, height);
            }
        }

        /// <summary>
        /// Returns the plugin registrar handle for the plugin with the given name.
        /// The name must be unique across the application.
        /// </summary>
        public FlutterDesktopPluginRegistrar GetRegistrarForPlugin(string pluginName)
        {
            if (Engine.IsValid)
            {
                return Engine.GetRegistrarForPlugin(pluginName);
            }
            return new FlutterDesktopPluginRegistrar();
        }
    }
}
