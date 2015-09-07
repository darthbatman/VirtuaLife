#include <pebble.h>

const int TESTKEY = 5;
const int ACCELKEY = 25;
  
static Window *s_main_window;
static TextLayer *s_text_layer;
static TextLayer *s_data_layer;

static bool sendingData = false;
static void data_handler(AccelData *data, uint32_t num_samples) {
  if (sendingData) {
    return;
  }
  
  // Long lived buffer
  static char s_buffer[128];

  // Compose string of all data for 3 samples
  snprintf(s_buffer, sizeof(s_buffer), 
    "%d,%d,%d,%llu",
    data[0].x, data[0].y, data[0].z, data[0].timestamp
  );
  
//   text_layer_set_text(s_data_layer, s_buffer);
  
  DictionaryIterator *iter;
  app_message_outbox_begin(&iter);
  dict_write_cstring(iter, ACCELKEY, s_buffer);
  app_message_outbox_send();
  sendingData = true;
}

static void outbox_sent_callback(DictionaryIterator *iterator, void *context) {
  sendingData = false;
}

static void send_int(int key, int value) {
  DictionaryIterator *iter;
  app_message_outbox_begin(&iter);
  dict_write_int(iter, key, &value, sizeof(int), true);
  app_message_outbox_send();
}

static void select_click_handler(ClickRecognizerRef recognizer, void *context) {
  send_int(TESTKEY, 1);
}

static void click_config_provider(void *context) {
  // Register the ClickHandlers
  window_single_click_subscribe(BUTTON_ID_SELECT, select_click_handler);
}

static void main_window_load(Window *window) {
  // Get the root layer
  Layer *window_layer = window_get_root_layer(window);

  // Get the bounds of the window for sizing the text layer
  GRect bounds = layer_get_bounds(window_layer);

  // Create and Add to layer hierarchy:
  s_text_layer = text_layer_create(GRect(0, 0, bounds.size.w, 40));
  text_layer_set_text(s_text_layer, "VirtuaLife");
  text_layer_set_font(s_text_layer, fonts_get_system_font(FONT_KEY_GOTHIC_28_BOLD));
  text_layer_set_text_color(s_text_layer, GColorBlack);
  text_layer_set_background_color(s_text_layer, GColorClear);
  text_layer_set_text_alignment(s_text_layer, GTextAlignmentCenter);
  layer_add_child(window_layer, text_layer_get_layer(s_text_layer));
  
  s_data_layer = text_layer_create(GRect(0, 60, bounds.size.w, 40));
  text_layer_set_text(s_data_layer, "Connected!");
  text_layer_set_text_color(s_data_layer, GColorBlack);
  text_layer_set_background_color(s_data_layer, GColorClear);
  text_layer_set_text_alignment(s_data_layer, GTextAlignmentCenter);
  layer_add_child(window_layer, text_layer_get_layer(s_data_layer));
}

static void main_window_unload(Window *window) {
  // Destroy TextLayer
  text_layer_destroy(s_text_layer);
  text_layer_destroy(s_data_layer);

  // Destroy Window
  window_destroy(window);
}

static void init() {
  // Open AppMessage
  app_message_open(app_message_inbox_size_maximum(), app_message_outbox_size_maximum());
  app_message_register_outbox_sent(outbox_sent_callback);
  
  // Create main Window
  s_main_window = window_create();
  window_set_window_handlers(s_main_window, (WindowHandlers) {
    .load = main_window_load,
    .unload = main_window_unload,
  });
  window_set_background_color(s_main_window, GColorIslamicGreen);
  window_set_click_config_provider(s_main_window, click_config_provider);
  uint32_t num_samples = 1;
  accel_data_service_subscribe(num_samples, data_handler);
  accel_service_set_sampling_rate(ACCEL_SAMPLING_10HZ);
  window_stack_push(s_main_window, true);
}

static void deinit() {
  // Destroy main Window
  window_destroy(s_main_window);
  accel_data_service_unsubscribe();
}

int main(void) {
  init();
  app_event_loop();
  deinit();
}