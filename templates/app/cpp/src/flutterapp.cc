#include "flutterapp.h"

#include <package_manager.h>
#include <system_info.h>

#include <string>
#include <vector>

#include "generated_plugin_registrant.h"

typedef struct appdata {
  FlutterWindowControllerRef window;
} appdata_s;

static bool app_create(void *data) {
  dlog_print(DLOG_DEBUG, LOG_TAG, "Launching a Flutter application...");

  FlutterWindowProperties window_prop = {};
  window_prop.x = 0;
  window_prop.y = 0;
  if (system_info_get_platform_int("http://tizen.org/feature/screen.width", &window_prop.width) != SYSTEM_INFO_ERROR_NONE ||
      system_info_get_platform_int("http://tizen.org/feature/screen.height", &window_prop.height) != SYSTEM_INFO_ERROR_NONE) {
    dlog_print(DLOG_ERROR, LOG_TAG, "Could not obtain the screen size.");
    return false;
  }

  package_info_h package_info;
  if (package_info_create(PACKAGE, &package_info) != PACKAGE_MANAGER_ERROR_NONE) {
    dlog_print(DLOG_ERROR, LOG_TAG, "Could not obtain the package information.");
    return false;
  }

  char *package_root;
  if (package_info_get_root_path(package_info, &package_root) != PACKAGE_MANAGER_ERROR_NONE) {
    dlog_print(DLOG_ERROR, LOG_TAG, "Could not obtain the package root path.");
    return false;
  }
  package_info_destroy(package_info);

  std::string base_dir(package_root);
  free(package_root);

  std::string assets_path(base_dir + "/res/flutter_assets");
  std::string icu_data_path(base_dir + "/res/icudtl.dat");
  std::string aot_lib_path(base_dir + "/lib/libapp.so");

  std::vector<const char *> switches = {};

  FlutterEngineProperties engine_prop = {};
  engine_prop.assets_path = assets_path.c_str();
  engine_prop.icu_data_path = icu_data_path.c_str();
  engine_prop.aot_library_path = aot_lib_path.c_str();
  engine_prop.switches = switches.data();
  engine_prop.switches_count = switches.size();

  auto window = FlutterCreateWindow(window_prop, engine_prop);
  if (!window) {
    dlog_print(DLOG_ERROR, LOG_TAG, "Could not launch a Flutter application.");
    return false;
  }

  RegisterPlugins(window);

  appdata_s *ad = (appdata_s *)data;
  ad->window = window;

  return true;
}

static void app_pause(void *data) {
  appdata_s *ad = (appdata_s *)data;
  if (ad->window) {
    FlutterNotifyAppIsPaused(ad->window);
  }
}

static void app_resume(void *data) {
  appdata_s *ad = (appdata_s *)data;
  if (ad->window) {
    FlutterNotifyAppIsResumed(ad->window);
  }
}

static void app_terminate(void *data) {
  dlog_print(DLOG_DEBUG, LOG_TAG, "Shutting down the application...");

  appdata_s *ad = (appdata_s *)data;
  if (ad->window) {
    FlutterDestroyWindow(ad->window);
    ad->window = nullptr;
  }
}

static void ui_app_lang_changed(app_event_info_h event_info, void *data) {
  appdata_s *ad = (appdata_s *)data;
  if (ad->window) {
    FlutterNotifyLocaleChange(ad->window);
  }
}

static void ui_app_region_changed(app_event_info_h event_info, void *data) {
  appdata_s *ad = (appdata_s *)data;
  if (ad->window) {
    FlutterNotifyLocaleChange(ad->window);
  }
}

static void ui_app_low_memory(app_event_info_h event_info, void *data) {
  appdata_s *ad = (appdata_s *)data;
  if (ad->window) {
    FlutterNotifyLowMemoryWarning(ad->window);
  }
}

int main(int argc, char *argv[]) {
  appdata_s ad = {};

  ui_app_lifecycle_callback_s event_callback = {};
  event_callback.create = app_create;
  event_callback.terminate = app_terminate;
  event_callback.pause = app_pause;
  event_callback.resume = app_resume;

  app_event_handler_h handlers[5] = {};
  ui_app_add_event_handler(&handlers[APP_EVENT_LOW_MEMORY], APP_EVENT_LOW_MEMORY, ui_app_low_memory, &ad);
  ui_app_add_event_handler(&handlers[APP_EVENT_LANGUAGE_CHANGED], APP_EVENT_LANGUAGE_CHANGED, ui_app_lang_changed, &ad);
  ui_app_add_event_handler(&handlers[APP_EVENT_REGION_FORMAT_CHANGED], APP_EVENT_REGION_FORMAT_CHANGED, ui_app_region_changed, &ad);

  int ret = ui_app_main(argc, argv, &event_callback, &ad);
  if (ret != APP_ERROR_NONE) {
    dlog_print(DLOG_ERROR, LOG_TAG, "Could not launch an application. (%d)", ret);
  }
  return ret;
}
