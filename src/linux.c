#include "linux.h"
#include <stdio.h>

#include <gtk/gtk.h>

extern void fl_view_set_background_color(GtkWidget *fl_view,
                                         const GdkRGBA *color);

EXPORT void cw_gtk_window_remove_decorations(void *gtk_window_,
                                             void *fl_view_) {
  GtkWidget *window = GTK_WIDGET(gtk_window_);
  gtk_window_set_decorated(GTK_WINDOW(window), FALSE);

  GtkWidget *fl_view = GTK_WIDGET(fl_view_);
  GdkRGBA color = {0, 0, 0, 0};
  fl_view_set_background_color(fl_view, &color);

  GtkStyleContext *style_context = gtk_widget_get_style_context(window);
  GtkCssProvider *provider = gtk_css_provider_new();
  gtk_css_provider_load_from_data(
      provider, "window { background-color: transparent; }", -1, NULL);
  gtk_style_context_add_provider(style_context, GTK_STYLE_PROVIDER(provider),
                                 GTK_STYLE_PROVIDER_PRIORITY_USER);
  g_object_unref(provider);
}

static GdkEvent *last_press_event;

static gboolean button_press_hook(GSignalInvocationHint *ihint,
                                  guint n_param_values,
                                  const GValue *param_values, gpointer data) {

  GdkEvent *event = (GdkEvent *)(g_value_get_boxed(param_values + 1));

  if (last_press_event != NULL) {
    gdk_event_free(last_press_event);
  }
  last_press_event = gdk_event_copy(event);

  return TRUE;
}

void cw_init_event_hooks_if_needed(void) {
  static bool initialized = false;
  if (initialized) {
    return;
  }
  initialized = true;

  g_signal_add_emission_hook(
      g_signal_lookup("button-press-event", GTK_TYPE_WIDGET), 0,
      button_press_hook, NULL, NULL);
}

static void synthesize_button_release() {
  if (last_press_event != NULL) {
    // Synthesize release event.
    GdkEvent *release_event = gdk_event_copy(last_press_event);
    release_event->type = GDK_BUTTON_RELEASE;
    gtk_main_do_event(release_event);
  } else {
    fprintf(stderr, "No last press event found\n");
  }
}

void cw_window_begin_move_drag(void *gtk_window, int x, int y) {
  GtkWidget *window = GTK_WIDGET(gtk_window);
  synthesize_button_release();

  gtk_window_begin_move_drag(GTK_WINDOW(window), GDK_BUTTON_PRIMARY, x, y,
                             GDK_CURRENT_TIME);
}

void cw_window_begin_resize_drag(void *gtk_window, cw_window_edge_t edge, int x,
                                 int y) {
  GtkWidget *window = GTK_WIDGET(gtk_window);
  synthesize_button_release();
  gtk_window_begin_resize_drag(GTK_WINDOW(window), (GdkWindowEdge)edge,
                               GDK_BUTTON_PRIMARY, x, y, GDK_CURRENT_TIME);
}

struct ShadowWidth {
  int top;
  int left;
  int bottom;
  int right;
};

static void set_shadow_width_on_realize(GtkWidget *widget, gpointer user_data) {
  struct ShadowWidth *shadow_width = (struct ShadowWidth *)user_data;
  GdkWindow *gdk_window = gtk_widget_get_window(widget);
  g_return_if_fail(gdk_window != NULL);
  gdk_window_set_shadow_width(gdk_window, shadow_width->top, shadow_width->left,
                              shadow_width->bottom, shadow_width->right);
  free(shadow_width);

  g_signal_handlers_disconnect_by_func(
      widget, G_CALLBACK(set_shadow_width_on_realize), user_data);
}

EXPORT void cw_window_set_shadow_width(void *gtk_window, int top, int left,
                                       int bottom, int right) {
  GtkWidget *window = GTK_WIDGET(gtk_window);
  GdkWindow *gdk_window = gtk_widget_get_window(window);
  if (gdk_window != NULL) {
    gdk_window_set_shadow_width(gdk_window, top, left, bottom, right);
  } else {
    struct ShadowWidth *shadow_width = malloc(sizeof(struct ShadowWidth));
    shadow_width->top = top;
    shadow_width->left = left;
    shadow_width->bottom = bottom;
    shadow_width->right = right;
    g_signal_connect(window, "realize", G_CALLBACK(set_shadow_width_on_realize),
                     shadow_width);
  }
}
typedef struct {
  cw_delegate_config_t config;
} cw_delegate_state_t;

static void cw_delegate_state_destroy(cw_delegate_state_t *state) {
  free(state);
}

static void cw_delegate_window_state_changed(GtkWindow *window,
                                             GdkEventWindowState *event,
                                             cw_delegate_state_t *state) {
  state->config.on_window_state_changed();
}

void cw_gtk_window_init_delegate(void *gtk_window,
                                 cw_delegate_config_t config) {
  GtkWidget *window = GTK_WIDGET(gtk_window);
  cw_delegate_state_t *state = malloc(sizeof(cw_delegate_state_t));
  state->config = config;

  g_signal_connect(window, "destroy", G_CALLBACK(config.on_window_will_close),
                   NULL);
  g_signal_connect(window, "window-state-event",
                   G_CALLBACK(cw_delegate_window_state_changed), state);
  g_object_weak_ref(G_OBJECT(window), (GWeakNotify)cw_delegate_state_destroy,
                    state);
}

cw_window_state_t cw_window_get_state(void *gtk_window) {
  GtkWidget *window = GTK_WIDGET(gtk_window);
  GdkWindow *gdk_window = gtk_widget_get_window(window);
  g_return_val_if_fail(gdk_window != NULL, 0);
  GdkWindowState state = gdk_window_get_state(gdk_window);
  return (cw_window_state_t)state;
}
