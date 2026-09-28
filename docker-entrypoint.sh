#!/bin/sh
set -e

# ==============================================================================
# Mosquitto Docker Entrypoint for Render
# ==============================================================================

CONFIG_FILE="/mosquitto/config/mosquitto.conf"
PWFILE="/mosquitto/config/pwfile"
ACLFILE="/mosquitto/config/aclfile"

echo "======================================================================"
echo " Starting Render MQTT Broker (Multi-Device over WebSocket)"
echo "======================================================================"

# ------------------------------------------------------------------------------
# 1. Dynamic Port Configuration (Render sets $PORT, default: 10000)
# ------------------------------------------------------------------------------
TARGET_PORT="${PORT:-10000}"
echo "--> Binding WebSocket listener to port: ${TARGET_PORT}"

# Replace WebSocket listener port in mosquitto.conf
if [ -f "$CONFIG_FILE" ]; then
    sed -i -E "s/^listener 10000/listener ${TARGET_PORT}/" "$CONFIG_FILE"
fi

# ------------------------------------------------------------------------------
# 2. Authentication & Credential Management
# ------------------------------------------------------------------------------
# Case A: Password file already mounted or copied into the container
if [ -s "$PWFILE" ]; then
    echo "--> Existing pwfile detected. Loading device credentials from file."

# Case B: Credentials supplied via Render Environment Variables
elif [ -n "$MQTT_DEVICES" ] || [ -n "$MQTT_USERNAME" ]; then
    echo "--> Generating pwfile from environment variables..."
    rm -f "$PWFILE" "$PWFILE.tmp"

    # Single admin / device user via MQTT_USERNAME and MQTT_PASSWORD
    if [ -n "$MQTT_USERNAME" ] && [ -n "$MQTT_PASSWORD" ]; then
        echo "--> Registering primary user: ${MQTT_USERNAME}"
        mosquitto_passwd -b -c "$PWFILE" "$MQTT_USERNAME" "$MQTT_PASSWORD"
    fi

    # Multiple devices via MQTT_DEVICES="dev1:pass1,dev2:pass2,admin:adminpass"
    if [ -n "$MQTT_DEVICES" ]; then
        echo "--> Registering device credentials from MQTT_DEVICES list..."
        OLD_IFS="$IFS"
        IFS=","
        for device_entry in $MQTT_DEVICES; do
            # Extract username and password (split on first colon)
            u=$(echo "$device_entry" | cut -d: -f1 | tr -d '[:space:]')
            p=$(echo "$device_entry" | cut -d: -f2- | tr -d '[:space:]')
            if [ -n "$u" ] && [ -n "$p" ]; then
                echo "    + Added device: $u"
                if [ ! -f "$PWFILE" ]; then
                    mosquitto_passwd -b -c "$PWFILE" "$u" "$p"
                else
                    mosquitto_passwd -b "$PWFILE" "$u" "$p"
                fi
            fi
        done
        IFS="$OLD_IFS"
    fi

# Case C: Fallback starter credentials so the broker does not crash on initial deploy
else
    echo "======================================================================"
    echo " [NOTICE] No pwfile found and no MQTT_DEVICES env vars specified."
    echo " Creating default starter credentials for quick verification:"
    echo "   User:     admin"
    echo "   Password: admin_changeme"
    echo "   Device:   esp32_device_01"
    echo "   Password: device_changeme"
    echo ""
    echo " [SECURITY ADVICE] Configure MQTT_DEVICES in Render Dashboard or"
    echo " supply a custom pwfile to secure your broker for production!"
    echo "======================================================================"
    rm -f "$PWFILE" "$PWFILE.tmp"
    mosquitto_passwd -b -c "$PWFILE" "admin" "admin_changeme"
    mosquitto_passwd -b "$PWFILE" "esp32_device_01" "device_changeme"
fi

# ------------------------------------------------------------------------------
# 3. Ownership and Permissions
# ------------------------------------------------------------------------------
chmod 0600 "$PWFILE"
if [ -f "$ACLFILE" ]; then
    chmod 0644 "$ACLFILE"
fi
chown -R mosquitto:mosquitto /mosquitto

# ------------------------------------------------------------------------------
# 4. Launch Mosquitto
# ------------------------------------------------------------------------------
echo "--> Launching Eclipse Mosquitto broker..."
exec /usr/sbin/mosquitto -c "$CONFIG_FILE"
