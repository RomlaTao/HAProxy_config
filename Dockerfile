# Use official HAProxy image
FROM haproxy:2.8-alpine

# Switch to root user to install packages
USER root

# Install OpenSSL for certificate generation
RUN apk update && apk add --no-cache openssl bash

# Create SSL directory
RUN mkdir -p /usr/local/etc/haproxy/ssl

# Copy HAProxy configuration
COPY haproxy.cfg /usr/local/etc/haproxy/haproxy.cfg

# Copy SSL certificate generation script
COPY generate-ssl.sh /usr/local/bin/generate-ssl.sh
RUN chmod +x /usr/local/bin/generate-ssl.sh

# Change to SSL directory and generate certificate
WORKDIR /usr/local/etc/haproxy/ssl
RUN /usr/local/bin/generate-ssl.sh

# Expose ports
EXPOSE 80 443 8403 8404

# Start HAProxy
CMD ["haproxy", "-f", "/usr/local/etc/haproxy/haproxy.cfg"] 