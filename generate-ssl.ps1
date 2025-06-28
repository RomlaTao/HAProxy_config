# PowerShell script to generate self-signed SSL certificate for HAProxy (Windows)

Write-Host "Generating self-signed SSL certificate for HAProxy..." -ForegroundColor Green

# Check if OpenSSL is available
try {
    & openssl version | Out-Null
} catch {
    Write-Host "OpenSSL not found. Please install OpenSSL first." -ForegroundColor Red
    Write-Host "You can download it from: https://slproweb.com/products/Win32OpenSSL.html" -ForegroundColor Yellow
    exit 1
}

# Create ssl directory at root level if it doesn't exist
if (!(Test-Path -Path "../ssl")) {
    New-Item -ItemType Directory -Path "../ssl"
    Write-Host "Created ssl directory at root level" -ForegroundColor Cyan
}

# Change to ssl directory at root level
Set-Location -Path "../ssl"

# Generate private key
Write-Host "Creating private key..." -ForegroundColor Yellow
& openssl genrsa -out haproxy.key 2048

# Generate certificate signing request
Write-Host "Creating certificate signing request..." -ForegroundColor Yellow
& openssl req -new -key haproxy.key -out haproxy.csr -subj "/C=VN/ST=HoChiMinh/L=HoChiMinh/O=HealthApp/CN=localhost"

# Generate self-signed certificate
Write-Host "Creating self-signed certificate..." -ForegroundColor Yellow
& openssl x509 -req -in haproxy.csr -signkey haproxy.key -out haproxy.crt -days 365

# Combine certificate and key for HAProxy
Write-Host "Creating combined PEM file for HAProxy..." -ForegroundColor Yellow
Get-Content haproxy.crt, haproxy.key | Set-Content haproxy.pem

# Clean up temporary files
Remove-Item haproxy.csr

Write-Host "SSL certificate generated successfully!" -ForegroundColor Green
Write-Host "Files created in root ssl/ directory:" -ForegroundColor Cyan
Write-Host "  - ssl/haproxy.key (private key)" -ForegroundColor White
Write-Host "  - ssl/haproxy.crt (certificate)" -ForegroundColor White
Write-Host "  - ssl/haproxy.pem (combined for HAProxy)" -ForegroundColor White

Write-Host "Certificate generation complete!" -ForegroundColor Green 