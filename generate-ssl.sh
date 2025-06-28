#!/bin/bash

# Generate self-signed SSL certificate for HAProxy (Development only)
echo "Generating self-signed SSL certificate for HAProxy..."

# Create ssl directory at root level if it doesn't exist
mkdir -p ../ssl
cd ../ssl

# Create private key
openssl genrsa -out haproxy.key 2048

# Create certificate signing request
openssl req -new -key haproxy.key -out haproxy.csr -subj "/C=VN/ST=HoChiMinh/L=HoChiMinh/O=HealthApp/CN=localhost"

# Create self-signed certificate
openssl x509 -req -in haproxy.csr -signkey haproxy.key -out haproxy.crt -days 365

# Combine certificate and key for HAProxy (PEM format)
cat haproxy.crt haproxy.key > haproxy.pem

# Clean up temporary files
rm haproxy.csr

echo "SSL certificate generated successfully!"
echo "Files created in root ssl/ directory:"
echo "  - ssl/haproxy.key (private key)"
echo "  - ssl/haproxy.crt (certificate)"
echo "  - ssl/haproxy.pem (combined for HAProxy)"

# Set appropriate permissions
chmod 600 haproxy.key haproxy.pem
chmod 644 haproxy.crt

echo "Certificate generation complete!" 