#pragma once

#include <stdbool.h>
#include <stddef.h>

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

EXPORT void cw_nswindow_update_draggable_areas(void *ns_window,
                                               cw_rect_t *exclude,
                                               size_t exclude_count);

EXPORT void cw_nswindow_disable_draggable_areas(void *ns_window);

EXPORT void cw_nswindow_update_traffic_light(void *ns_window, bool enabled,
                                             double x, double y);

EXPORT void cw_nswindow_request_close(void *ns_window);

#ifdef __cplusplus
}
#endif