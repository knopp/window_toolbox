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

typedef struct {
  void (*on_window_will_close)();
  void (*on_window_state_changed)();
} cw_delegate_config_t;

EXPORT void cw_gtk_window_init_delegate(void *gtk_window,
                                        cw_delegate_config_t config);

typedef int cw_window_state_t;
const cw_window_state_t CW_WINDOW_STATE_WITHDRAWN = 1 << 0;
const cw_window_state_t CW_WINDOW_STATE_ICONIFIED = 1 << 1;
const cw_window_state_t CW_WINDOW_STATE_MAXIMIZED = 1 << 2;
const cw_window_state_t CW_WINDOW_STATE_STICKY = 1 << 3;
const cw_window_state_t CW_WINDOW_STATE_FULLSCREEN = 1 << 4;
const cw_window_state_t CW_WINDOW_STATE_ABOVE = 1 << 5;
const cw_window_state_t CW_WINDOW_STATE_BELOW = 1 << 6;
const cw_window_state_t CW_WINDOW_STATE_FOCUSED = 1 << 7;
const cw_window_state_t CW_WINDOW_STATE_TILED = 1 << 8; // Deprecated.
const cw_window_state_t CW_WINDOW_STATE_TOP_TILED = 1 << 9;
const cw_window_state_t CW_WINDOW_STATE_TOP_RESIZABLE = 1 << 10;
const cw_window_state_t CW_WINDOW_STATE_RIGHT_TILED = 1 << 11;
const cw_window_state_t CW_WINDOW_STATE_RIGHT_RESIZABLE = 1 << 12;
const cw_window_state_t CW_WINDOW_STATE_BOTTOM_TILED = 1 << 13;
const cw_window_state_t CW_WINDOW_STATE_BOTTOM_RESIZABLE = 1 << 14;
const cw_window_state_t CW_WINDOW_STATE_LEFT_TILED = 1 << 15;
const cw_window_state_t CW_WINDOW_STATE_LEFT_RESIZABLE = 1 << 16;

EXPORT cw_window_state_t cw_window_get_state(void *gtk_window);
