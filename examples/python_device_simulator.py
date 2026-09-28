#!/usr/bin/env python3
"""
Multi-Device Python MQTT Simulator over WebSocket
Connects to the Render MQTT broker using WebSockets (ws or wss).
Publishes telemetry and receives targeted device commands.

Requirements:
    pip install paho-mqtt
"""

import sys
import time
import json
import random
import argparse
import paho.mqtt.client as mqtt

def parse_args():
    parser = argparse.ArgumentParser(description="Simulate an IoT device over MQTT WebSocket")
    parser.add_argument("--host", default="localhost", help="Broker host (e.g. localhost or your-app.onrender.com)")
    parser.add_argument("--port", type=int, default=10000, help="Broker port (default: 10000 for local ws, 443 for Render wss)")
    parser.add_argument("--protocol", choices=["ws", "wss"], default="ws", help="WebSocket protocol (ws or wss)")
    parser.add_argument("--device-id", default="esp32_device_01", help="Unique Device ID")
    parser.add_argument("--username", default="esp32_device_01", help="Device username (must match device ID)")
    parser.add_argument("--password", default="device_changeme", help="Device password")
    parser.add_argument("--interval", type=int, default=3, help="Telemetry publish interval in seconds")
    return parser.parse_args()

def on_connect(client, userdata, flags, rc, properties=None):
    device_id = userdata["device_id"]
    if rc == 0:
        print(f"[SUCCESS] Connected to MQTT broker over WebSocket as '{device_id}'")
        command_topic = f"devices/{device_id}/command"
        status_topic = f"devices/{device_id}/status"
        
        # Subscribe to device-specific commands
        client.subscribe(command_topic, qos=1)
        print(f"[SUBSCRIBED] Listening for commands on: {command_topic}")

        # Publish online status
        client.publish(status_topic, json.dumps({"status": "online", "device": device_id}), qos=1, retain=True)
    else:
        print(f"[ERROR] Connection failed with return code {rc}")

def on_message(client, userdata, msg):
    print(f"\n[COMMAND RECEIVED] Topic: {msg.topic}")
    try:
        payload = json.loads(msg.payload.decode())
        print(f"Payload (JSON): {json.dumps(payload, indent=2)}")
    except Exception:
        print(f"Payload: {msg.payload.decode()}")

def main():
    args = parse_args()
    telemetry_topic = f"devices/{args.device_id}/telemetry"
    status_topic = f"devices/{args.device_id}/status"

    print("=================================================================")
    print(f" Simulating IoT Device: {args.device_id}")
    print(f" Broker: {args.protocol}://{args.host}:{args.port}")
    print(f" Telemetry topic: {telemetry_topic}")
    print("=================================================================")

    # Initialize MQTT client with WebSockets transport
    # Note: Compatible with paho-mqtt v1.x and v2.x
    client = mqtt.Client(
        client_id=args.device_id,
        transport="websockets",
        userdata={"device_id": args.device_id}
    )

    client.username_pw_set(args.username, args.password)
    client.on_connect = on_connect
    client.on_message = on_message

    # Configure Last Will and Testament (LWT)
    client.will_set(status_topic, json.dumps({"status": "offline", "device": args.device_id}), qos=1, retain=True)

    # Configure TLS for secure wss connections (Render endpoints)
    if args.protocol == "wss":
        import ssl
        client.tls_set(cert_reqs=ssl.CERT_REQUIRED, tls_version=ssl.PROTOCOL_TLS_CLIENT)

    try:
        client.connect(args.host, args.port, keepalive=60)
        client.loop_start()

        while True:
            # Generate simulated sensor reading
            telemetry_data = {
                "deviceId": args.device_id,
                "temperature": round(23.0 + random.uniform(-2.5, 2.5), 2),
                "humidity": round(50.0 + random.uniform(-10.0, 10.0), 1),
                "battery": round(random.uniform(3.7, 4.2), 2),
                "timestamp": int(time.time())
            }

            client.publish(telemetry_topic, json.dumps(telemetry_data), qos=1)
            print(f"[TELEMETRY PUBLISHED] {telemetry_data}")
            time.sleep(args.interval)

    except KeyboardInterrupt:
        print("\n[STOPPING] Disconnecting device...")
        client.publish(status_topic, json.dumps({"status": "offline", "device": args.device_id}), qos=1, retain=True)
        client.loop_stop()
        client.disconnect()
        print("Disconnected cleanly.")

if __name__ == "__main__":
    main()
