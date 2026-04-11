#pragma once

#include <stdbool.h>
#include <stddef.h>

#define EXPORT __attribute__((visibility("default")))

typedef enum {
  CW_WINDOW_EDGE_NORTH_WEST,
  CW_WINDOW_EDGE_NORTH,
  CW_WINDOW_EDGE_NORTH_EAST,
  CW_WINDOW_EDGE_WEST,
  CW_WINDOW_EDGE_EAST,
  CW_WINDOW_EDGE_SOUTH_WEST,
  CW_WINDOW_EDGE_SOUTH,
  CW_WINDOW_EDGE_SOUTH_EAST
} cw_window_edge_t;

EXPORT void cw_gtk_window_remove_decorations(void *gtk_window, void *fl_view);
EXPORT void cw_init_event_hooks_if_needed(void);
EXPORT void cw_window_begin_move_drag(void *gtk_window, int x, int y);
EXPORT void cw_window_begin_resize_drag(void *gtk_window, cw_window_edge_t edge,
                                        int x, int y);
EXPORT void cw_window_set_shadow_width(void *gtk_window, int top, int left,
                                       int bottom, int right);