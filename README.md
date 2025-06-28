# Cấu Hình HAProxy Load Balancer

## Tổng Quan

File `haproxy.cfg` định nghĩa cấu hình cho HAProxy Load Balancer trong hệ thống Health App, bao gồm SSL termination, load balancing và routing cho các microservices.

## Cấu Trúc File Cấu Hình

### 1. Global Settings
```cfg
global
    log stdout format raw local0 info
    maxconn 4000
    stats socket /tmp/haproxy.sock mode 660 level admin
    stats timeout 30s
```

**Giải thích:**
- `log stdout`: Ghi log ra stdout để Docker có thể thu thập
- `maxconn 4000`: Giới hạn tối đa 4000 kết nối đồng thời
- `stats socket`: Tạo Unix socket để quản lý HAProxy qua command line
- `stats timeout 30s`: Timeout cho stats commands

### 2. SSL Configuration (Global)
```cfg
ssl-default-bind-ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384
ssl-default-bind-options ssl-min-ver TLSv1.2 no-tls-tickets
```

**Giải thích:**
- `ssl-default-bind-ciphers`: Định nghĩa cipher suites mạnh cho kết nối SSL
- `ssl-min-ver TLSv1.2`: Chỉ chấp nhận TLS 1.2 trở lên
- `no-tls-tickets`: Tắt TLS session tickets để bảo mật tốt hơn

### 3. Default Settings
```cfg
defaults
    mode http
    log global
    option httplog
    timeout client 30s
    timeout connect 10s
    timeout server 240s
    timeout http-request 10s
    option forwardfor
```

**Giải thích:**
- `mode http`: Hoạt động ở layer 7 (HTTP/HTTPS)
- `option httplog`: Log chi tiết HTTP requests
- `timeout client 30s`: Client timeout sau 30 giây
- `timeout connect 10s`: Timeout kết nối backend sau 10 giây
- `timeout server 240s`: Server response timeout sau 4 phút
- `option forwardfor`: Thêm X-Forwarded-For header

## Frontend Configurations

### 4. HTTP Frontend (Port 80)
```cfg
frontend api_http
    bind *:80
    mode http

    # Define ACLs first
    acl is_health_check path /health
    acl is_discovery_ui path_beg /eureka
    acl is_actuator path_beg /actuator

    # Health check endpoint - bypass redirect
    http-request return status 200 content-type text/plain string "OK" if is_health_check

    # Discovery Server UI access
    use_backend discovery_backend if is_discovery_ui

    # Actuator endpoints
    use_backend api_backend if is_actuator

    # All other requests to API backend
    default_backend api_backend
```

**Giải thích:**
- **ACLs (Access Control Lists)**:
  - `is_health_check`: Kiểm tra path `/health` cho load balancer health checks
  - `is_discovery_ui`: Path bắt đầu với `/eureka` cho Eureka dashboard
  - `is_actuator`: Path bắt đầu với `/actuator` cho monitoring endpoints

- **Routing Logic**:
  - Health check trả về "OK" ngay lập tức
  - Eureka UI được route tới `discovery_backend`
  - Actuator endpoints được route tới `api_backend`
  - Tất cả requests khác đều đi tới `api_backend`

### 5. HTTPS Frontend (Port 443)
```cfg
frontend api_https
    bind *:443 ssl crt /usr/local/etc/haproxy/ssl/haproxy.pem
    mode http
    log global
    option httplog
    option logasap
    option log-health-checks

    # Debug logging
    capture request header Host len 32
    capture request header Content-Type len 32
    capture request header Content-Length len 10

    # Add secure headers
    http-request set-header X-Forwarded-Proto https if { ssl_fc }
    http-request set-header X-Forwarded-Port %[dst_port]

    # Security Headers
    http-response set-header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
    http-response set-header X-Frame-Options DENY
    http-response set-header X-Content-Type-Options nosniff
    http-response set-header X-XSS-Protection "1; mode=block"

    # Discovery Server UI access
    acl is_discovery_ui path_beg /eureka
    use_backend discovery_backend if is_discovery_ui

    # Default to API backend
    default_backend api_backend
```

**Giải thích:**
- **SSL Binding**: 
  - `bind *:443 ssl crt`: Bind port 443 với SSL certificate
  - Certificate path: `/usr/local/etc/haproxy/ssl/haproxy.pem`

- **Logging**:
  - `option logasap`: Log ngay khi nhận request
  - `capture request header`: Ghi lại các headers quan trọng

- **Security Headers**:
  - `X-Frame-Options DENY`: Ngăn clickjacking
  - `X-Content-Type-Options nosniff`: Ngăn MIME type sniffing
  - `X-XSS-Protection`: Bật XSS protection

- **Forwarded Headers**:
  - `X-Forwarded-Proto https`: Báo cho backend biết đây là HTTPS request
  - `X-Forwarded-Port`: Báo port gốc

## Backend Configurations

### 6. API Backend
```cfg
backend api_backend
    balance roundrobin
    option httpchk GET /actuator/health
    option http-buffer-request

    # Backend servers using container names
    server api-service-1 api-service-1:8080 check port 8080
    server api-service-2 api-service-2:8080 check port 8080
```

**Giải thích:**
- `balance roundrobin`: Phân phối requests theo vòng tròn
- `option httpchk GET /actuator/health`: Health check endpoint
- `option http-buffer-request`: Buffer request trước khi gửi tới backend
- **Servers**:
  - `api-service-1:8080`: Container name và port của API Gateway instance 1
  - `api-service-2:8080`: Container name và port của API Gateway instance 2
  - `check port 8080`: Kiểm tra health trên port 8080

### 7. Discovery Backend
```cfg
backend discovery_backend
    balance roundrobin
    option httpchk GET /actuator/health

    # Discovery server using container name
    server discovery-server discovery-server:8761 check port 8761
```

**Giải thích:**
- Tương tự API backend nhưng chỉ có 1 server
- `discovery-server:8761`: Container name và port của Eureka Server

## Stats Configuration

### 8. HTTPS Stats Frontend (Port 8404)
```cfg
frontend stats_https
    bind *:8404 ssl crt /usr/local/etc/haproxy/ssl/haproxy.pem
    mode http

    # Basic Authentication
    stats auth admin:12345

    stats enable
    stats uri /
    stats refresh 10s
    stats show-legends
    stats admin if TRUE

    # Security headers
    http-response set-header Strict-Transport-Security "max-age=31536000; includeSubDomains"
```

**Giải thích:**
- **SSL Stats**: Dashboard chỉ có thể truy cập qua HTTPS
- **Authentication**: Username `admin`, password `12345`
- **Stats Settings**:
  - `stats uri /`: Dashboard tại root path `/`
  - `stats refresh 10s`: Tự động refresh mỗi 10 giây
  - `stats show-legends`: Hiển thị chú thích
  - `stats admin if TRUE`: Cho phép admin operations

### 9. HTTP Stats Redirect (Port 8403)
```cfg
frontend stats_http
    bind *:8403
    mode http
    
    # Redirect HTTP stats to HTTPS for security
    redirect scheme https code 301
```

**Giải thích:**
- Port 8403 chỉ để redirect HTTP sang HTTPS
- `redirect scheme https code 301`: Chuyển hướng vĩnh viễn sang HTTPS

## Chiến Lược Routing

### HTTP vs HTTPS
- **Port 80 (HTTP)**: Cho phép một số endpoints cụ thể (health check, eureka, actuator)
- **Port 443 (HTTPS)**: Entry point chính cho tất cả API requests

### Load Balancing
- **Algorithm**: Round Robin giữa 2 API Gateway instances
- **Health Checks**: Kiểm tra `/actuator/health` mỗi vài giây
- **Failover**: Tự động loại bỏ instance bị lỗi khỏi pool

### Security
- **SSL Termination**: HAProxy xử lý SSL, backend nhận HTTP
- **Security Headers**: Tự động thêm vào mọi HTTPS response
- **TLS 1.2+**: Chỉ chấp nhận phiên bản TLS mới

## Monitoring và Debug

### Access Logs
```cfg
option httplog
option logasap
capture request header Host len 32
```

### Health Checks
```cfg
option httpchk GET /actuator/health
server api-service-1 api-service-1:8080 check port 8080
```

### Stats Dashboard
- **URL**: https://localhost:8404
- **Credentials**: admin/12345
- **Features**: Real-time metrics, server status, admin controls 