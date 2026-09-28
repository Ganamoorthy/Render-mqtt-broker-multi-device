FROM eclipse-mosquitto:latest

LABEL maintainer="Render MQTT Multi-Device"
LABEL description="MQTT Broker over WebSocket designed for Render Docker Web Services"

# Create standard directories (including http directory for dashboard & Render health checks)
RUN mkdir -p /mosquitto/config /mosquitto/data /mosquitto/log /mosquitto/ssl /mosquitto/http

# Copy web test dashboard to serve as HTTP index page (satisfies Render HTTP port scanner)
COPY test-client.html /mosquitto/http/index.html

# Copy Mosquitto configuration and Access Control List (ACL)
COPY mosquitto.conf aclfile /mosquitto/config/

# Copy password file example and any optional local pwfile
COPY pwfile* /mosquitto/config/

# Copy and setup entrypoint script
COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh && \
    chown -R mosquitto:mosquitto /mosquitto

# Ports: 10000 (Render WebSocket & HTTP)
EXPOSE 10000

# Set entrypoint to initialize ports and credentials before starting Mosquitto
ENTRYPOINT ["/docker-entrypoint.sh"]
