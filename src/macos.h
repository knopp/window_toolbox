#pragma once

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define EXPORT __attribute__((visibility("default")))

EXPORT void cw_nswindow_remove_titlebar(void *ns_window);

typedef struct {
  double x;
  double y;
  double w;
  double h;
} cw_rect_t;

typedef struct {
  double w;
  double h;
} cw_size_t;

EXPORT void cw_nswindow_update_draggable_areas(void *ns_window,
                                               cw_rect_t *exclude,
                                               size_t exclude_count);

EXPORT void cw_nswindow_disable_draggable_areas(void *ns_window);

typedef enum {
  CW_APPEARANCE_AUTO,
  CW_APPEARANCE_LIGHT,
  CW_APPEARANCE_DARK,
} cw_appearance_t;

typedef struct {
  double offset_x;
  double offset_y;
  cw_appearance_t appearance;
  bool custom_inactive_traffic_light;
  int64_t inactive_background_color;
  int64_t inactive_border_color;
  double inactive_border_width;
  bool show_as_inactive_in_key_window;
} cw_traffic_light_config_t;

EXPORT void
cw_nswindow_update_traffic_light(void *ns_window,
                                 const cw_traffic_light_config_t *config);

EXPORT cw_size_t cw_nswindow_traffic_light_size(void *ns_window);

EXPORT void cw_nswindow_request_close(void *ns_window);

EXPORT void cw_nswindow_set_style_mask(void *ns_window,
                                       unsigned long style_mask);

EXPORT unsigned long cw_nswindow_get_style_mask(void *ns_window);

EXPORT void
cw_nswindow_set_collection_behavior(void *ns_window,
                                    unsigned long collection_behavior);

EXPORT unsigned long cw_nswindow_get_collection_behavior(void *ns_window);

typedef struct {
  cw_size_t (*on_window_will_resize)(cw_size_t new_size);
  void (*on_window_will_close)();
  void (*on_window_will_enter_fullscreen)();
  void (*on_window_did_enter_fullscreen)();
  void (*on_window_will_exit_fullscreen)();
  void (*on_window_did_exit_fullscreen)();
  cw_rect_t (*on_window_will_use_standard_frame)(cw_rect_t default_frame);
} cw_delegate_config_t;

EXPORT void cw_nswindow_init_delegate(void *ns_window,
                                      cw_delegate_config_t config);

#ifdef __cplusplus
}
#endif