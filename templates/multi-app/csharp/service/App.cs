using Tizen.Flutter.Embedding;

namespace Runner
{
    public class App : FlutterServiceApplication
    {
        protected override void OnCreate()
        {
            DartEntrypoint = "serviceMain";
            base.OnCreate();

            GeneratedPluginRegistrant.RegisterPlugins(this);
        }

        static void Main(string[] args)
        {
            var app = new App();
            app.Run(args);
        }
    }
}
