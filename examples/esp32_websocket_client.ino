/*
  ==============================================================================
  ESP32 MQTT over WebSocket (WSS) Client Example
  Target: ESP32 / ESP32-S3 / ESP32-C3
  Broker: Render MQTT Web Service (wss://<your-service>.onrender.com)
  ==============================================================================
  This sketch uses the ESP32's built-in esp-mqtt client (included in Arduino ESP32 core)
  which natively supports MQTT over Secure WebSockets (WSS). No external MQTT
  libraries needed!
  ==============================================================================
*/

#include <WiFi.h>
#include "mqtt_client.h"

// -----------------------------------------------------------------------------
// 1. Wi-Fi & Broker Configuration
// -----------------------------------------------------------------------------
const char* WIFI_SSID     = "YOUR_WIFI_SSID";
const char* WIFI_PASSWORD = "YOUR_WIFI_PASSWORD";

// Render app URL (Use wss:// and port 443)
// For local testing: "ws://192.168.1.100:10000"
const char* BROKER_URI    = "wss://your-app-name.onrender.com:443";

// Unique Device Identity
const char* DEVICE_ID     = "esp32_device_01";
const char* MQTT_USERNAME = "esp32_device_01";
const char* MQTT_PASSWORD = "device_changeme";

// Topic definitions (Isolated namespace enforced by broker ACL)
String topicTelemetry = String("devices/") + DEVICE_ID + "/telemetry";
String topicStatus    = String("devices/") + DEVICE_ID + "/status";
String topicCommand   = String("devices/") + DEVICE_ID + "/command";

esp_mqtt_client_handle_t mqtt_client = NULL;
unsigned long lastTelemetryMillis = 0;

// -----------------------------------------------------------------------------
// 2. MQTT Event Callback Handler
// -----------------------------------------------------------------------------
static esp_err_t mqtt_event_handler_cb(esp_mqtt_event_handle_t event) {
    switch (event->event_id) {
        case MQTT_EVENT_CONNECTED:
            Serial.println("[MQTT] Connected to WebSocket broker!");
            
            // Subscribe to incoming commands for this specific device
            esp_mqtt_client_subscribe(mqtt_client, topicCommand.c_str(), 1);
            Serial.printf("[MQTT] Subscribed to commands: %s\n", topicCommand.c_str());

            // Publish online status
            esp_mqtt_client_publish(mqtt_client, topicStatus.c_str(), "{\"status\":\"online\"}", 0, 1, 1);
            break;

        case MQTT_EVENT_DISCONNECTED:
            Serial.println("[MQTT] Disconnected from broker. Will auto-reconnect...");
            break;

        case MQTT_EVENT_DATA:
            Serial.printf("[MQTT] Incoming Message on topic: %.*s\n", event->topic_len, event->topic);
            Serial.printf("[MQTT] Payload: %.*s\n", event->data_len, event->data);
            
            // Example: Handle command execution
            // if (strncmp(event->data, "TOGGLE_LED", event->data_len) == 0) { ... }
            break;

        case MQTT_EVENT_ERROR:
            Serial.println("[MQTT] Event Error encountered.");
            break;

        default:
            break;
    }
    return ESP_OK;
}

static void mqtt_event_handler(void *handler_args, esp_event_base_t base, int32_t event_id, void *event_data) {
    mqtt_event_handler_cb((esp_mqtt_event_handle_t)event_data);
}

// -----------------------------------------------------------------------------
// 3. Initialize MQTT Client
// -----------------------------------------------------------------------------
void initMQTT() {
    esp_mqtt_client_config_t mqtt_cfg = {};
    mqtt_cfg.uri = BROKER_URI;
    mqtt_cfg.client_id = DEVICE_ID;
    mqtt_cfg.username = MQTT_USERNAME;
    mqtt_cfg.password = MQTT_PASSWORD;
    mqtt_cfg.transport = MQTT_TRANSPORT_OVER_WSS;
    mqtt_cfg.disable_auto_reconnect = false;

    // Last Will and Testament (LWT) published if connection is dropped unexpectedly
    mqtt_cfg.lwt_topic = topicStatus.c_str();
    mqtt_cfg.lwt_msg = "{\"status\":\"offline\"}";
    mqtt_cfg.lwt_qos = 1;
    mqtt_cfg.lwt_retain = 1;

    Serial.println("[MQTT] Initializing client...");
    mqtt_client = esp_mqtt_client_init(&mqtt_cfg);
    esp_mqtt_client_register_event(mqtt_client, (esp_mqtt_event_id_t)ESP_EVENT_ANY_ID, mqtt_event_handler, NULL);
    esp_mqtt_client_start(mqtt_client);
}

// -----------------------------------------------------------------------------
// 4. Arduino Setup & Loop
// -----------------------------------------------------------------------------
void setup() {
    Serial.begin(115200);
    delay(1000);
    Serial.println("\n--- Starting ESP32 MQTT WebSocket Client ---");

    // Connect to Wi-Fi
    WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
    Serial.print("Connecting to Wi-Fi");
    while (WiFi.status() != WL_CONNECTED) {
        delay(500);
        Serial.print(".");
    }
    Serial.printf("\nWi-Fi Connected! IP: %s\n", WiFi.localIP().toString().c_str());

    // Connect to MQTT Broker
    initMQTT();
}

void loop() {
    // Publish telemetry every 5 seconds
    if (millis() - lastTelemetryMillis > 5000) {
        lastTelemetryMillis = millis();

        // Sample sensor reading
        float temperature = 24.5 + (random(-10, 10) / 10.0);
        float humidity = 55.0 + (random(-20, 20) / 10.0);

        char payload[128];
        snprintf(payload, sizeof(payload),
                 "{\"deviceId\":\"%s\",\"temp\":%.1f,\"humidity\":%.1f,\"uptime\":%lu}",
                 DEVICE_ID, temperature, humidity, millis() / 1000);

        if (mqtt_client != NULL) {
            int msg_id = esp_mqtt_client_publish(mqtt_client, topicTelemetry.c_str(), payload, 0, 1, 0);
            Serial.printf("[TELEMETRY] Sent (msg_id: %d): %s\n", msg_id, payload);
        }
    }
    delay(10);
}
