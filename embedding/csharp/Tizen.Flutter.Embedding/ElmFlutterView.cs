using System;
using System.Diagnostics;
using ElmSharp;
using static Tizen.Flutter.Embedding.Interop;

namespace Tizen.Flutter.Embedding
{
    // TODO: Revisit EvasObject.cs implementation.
    // TODO: consider renaming EvasObjectImpl.
    // TODO: Add documentation.
    // TODO(another PR): Format the C# code.
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

    public class ElmFlutterView : IPluginRegistry
    {
        private FlutterEngine Engine { get; set; } = null;

        private FlutterDesktopView View { get; set; } = new FlutterDesktopView();

        public EvasObject EvasObject { get; private set; } = null;

        private EvasObject Parent { get; set; } = null;

        private int InitialWidth { get; set; } = 0;

        private int InitialHeight { get; set; } = 0;

        public bool IsRunning => !View.IsInvalid;

        public int Width
        {
            get
            {
                Debug.Assert(IsRunning);

                return EvasObject.Geometry.Width;
            }
        }

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
