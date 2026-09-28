# ==============================================================================
# Dockerfile: Multi-Device MQTT Broker over WebSocket for Render
# Base: Eclipse Mosquitto
# ==============================================================================

FROM eclipse-mosquitto:latest

LABEL maintainer="Render MQTT Multi-Device"
LABEL description="MQTT Broker over WebSocket designed for Render Docker Web Services"

# Create standard directories
RUN mkdir -p /mosquitto/config /mosquitto/data /mosquitto/log /mosquitto/ssl

# Copy Mosquitto configuration and Access Control List (ACL)
COPY mosquitto.conf aclfile /mosquitto/config/

# Copy password file example and any optional local pwfile (wildcard avoids build failure if pwfile is absent)
COPY pwfile* /mosquitto/config/

# Copy optional SSL certificates directory
COPY ssl/ /mosquitto/ssl/

# Copy and setup entrypoint script
COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh && \
    chown -R mosquitto:mosquitto /mosquitto

# Ports: 10000 (Render WebSocket), 1883 (Standard TCP MQTT), 8883 (MQTTS TLS)
EXPOSE 10000 1883 8883

# Set entrypoint to initialize ports and credentials before starting Mosquitto
ENTRYPOINT ["/docker-entrypoint.sh"]
