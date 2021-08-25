#include "runner.h"

#include "generated_plugin_registrant.h"

class App : public FlutterServiceApp {
 public:
  bool OnCreate() {
    if (FlutterServiceApp::OnCreate()) {
      RegisterPlugins(this);
    }
    return IsRunning();
  }
};

int main(int argc, char *argv[]) {
  App app;
  return app.Run(argc, argv);
}
