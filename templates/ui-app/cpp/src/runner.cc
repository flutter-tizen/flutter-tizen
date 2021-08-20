#include "runner.h"

#include "generated_plugin_registrant.h"

class App : public FlutterApp {
 public:
  bool OnCreate() {
    if (FlutterApp::OnCreate()) {
      RegisterPlugins(this);
    }
    return IsRunning();
  }
};

int main(int argc, char *argv[]) {
  App app;
  return app.Run(argc, argv);
}
