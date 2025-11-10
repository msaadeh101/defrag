# NGINX

## Background

**nginx** is an HTTP web server, reverse proxy, content cache, load balancer, TCP/UDP proxy server, and mail proxy server. nginx can be installed for various platforms from nginx.org. Here are the [Ubuntu installation instructions](https://nginx.org/en/linux_packages.html#Ubuntu).

## Features

### Core Features

|Feature|Description| Use Case/Example|
|-------|-------------|---------------|
|**Static file serving**| Serves static assets (`HTML`, `CSS`, `JS`) directly.| Useful for lightweight frontend hosting or service dashboards.|
| **Reverse Proxy** | Routes client requests to one or more backend services. | Core for decoupling clients from service topology (e.g. `/api/user` -> `user-service`) |
| **Load Balancing** | Distributes requests across multiple backends.  | Ensures horizontal scalability and resilience. |
|**Health checks**| Detects failed backends and removes them temporarily|Keeps traffic flowing to healthy pods/VMs.|
|**SSL/TLS Termination**| Handles HTTPS at the edge.| Offloads expensive crypto from app services.|
|**Caching**|Stores responses for faster delivery.| Reduces load on microservices/databases.|
|**Compression (`gzip`, `brotli`)**| Compresses responses to reduce bandwidth| Improves latency.|
|**Connection Management**| Manages Keep-alive, connection pooling, timeouts.| Optimizes throughput under heavy load.|

### Advanced Features

|Feature|Description| Use Case/Example|
|-------|-------------|---------------|
|**Advanced LB Algorithms**| `least_conn`, `ip_hash`, `hash`, `random`| Sticky sessions or load distribution for stateful microservices.|
|**Active & Passive Health Checks**| Detects failing services at configurable intervals|Keeps auto-scaled microservices healthy.|
|**Rate Limiting and Burst Control**| Controls request rate per IP/Key/User.| Prevents DDoS, Noisy-neighbors.|
|**Request Routing & Path Rewriting**| `rewrite`, `map`, `try_files` directives.| Route `/v1/users` -> new `user-service-v2` without client change.|
|**Header Manipulation**|Add/remove/transform headers.|Inject auth headers, trace IDs, or CORS config.|
|**Access Control Lists (ACLs)**| IP whitelisting, allow/deny logic.|Restrict internal APIs or admin routes.|
|**JWT & OAuth2 Integration** (NGINX Plus or Lua)| Validate tokens at the edge.| Enforce auth before hitting backend microservices.|
|**Upstream Connection Reuse (`keepalive`)**| Reuses TCP connections to backends.| Huge performance gain for chatty microservices.|
|**Observability Hooks (`stub_status`, log formats)**| Exposes metrics for Prometheus/Grafana| Traffic Dashboards or Autoscaling triggers.|
|**Request & Response Buffering**| Smooths out *bursty* client behavior.| Prevents backpressure overloads.|
|**Custom Logging (Structured JSON)**| Fine-grained, machine-readable logs.| Centralized logging in ELK/Splunk.|

### Security Features

|Feature|Description| Use Case/Example|
|-------|-------------|---------------|
|**WAF (Web Application Firewall)**| Detects and blocks common attack patterns.| Protects APIs against OWASP TOP 10 attacks.|
|**mTLS (Mutual TLS)**| Client cert validation for internal services.| Ensures **zero-trust** between microservices.|
|**Certificate Management (`ACME`/`certbot`)**|Automated SSL renewals with zero downtime.|Avoids manual certificate rotation.|
|**Request Validation**| Enforce size limits, content types, methods.| Protects backends from malformed requests.|
|**Security Headers**|Add `HSTS`, `CSP`, `XSS` headers.| Hardens public-facing endpoints.|

## Configuration

### nginx.conf

- The `nginx.conf` file is the main config file for NGINX that controls the behavior of the web server and reverse proxy. It defines the settings for logging, worker processes, connections, server blocks (virtual hosts), upstream backends, security, and performance tuning.

- By default, its located in `/etc/nginx/nginx.conf` on most Linux systems.

#### Structure and Key Sections

- **Main context**: Global settings for the NGINX master process (`worker_processes`, `error_log`).
- **Events context**: Settings affecting how worker processes handle connections (`worker_connections`).
- **HTTP context**: Contains directives related to web traffic (HTTP/HTTPS) including server blocks, upstreams, caching, compression, etc.
- **Server blocks**: Define virtual hosts to respond to requests based on domain, IP, or port.
- **Location blocks**: Define how to process requests for specific URIs.

```t
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log warn;
pid /var/run/nginx.pid;

events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    log_format main '$remote_addr - $remote_user [$time_local] '
                    '"$request" $status $body_bytes_sent '
                    '"$http_referer" "$http_user_agent"';

    access_log /var/log/nginx/access.log main;
    sendfile on;

    server {
        listen 80;
        server_name example.com;

        location / {
            root /usr/share/nginx/html;
            index index.html index.htm;
        }
    }
}
```

- `worker_processes`: Controls how many worker processes NGINX spawns. Usually this is set to number of CPU cores or `auto`.
- `worker_connections`: Number of connections each worker can handle concurrently.
- `sendfile`: Enables kernel-level file transfer for better performance.
- `keepalive_timeout`: Controls how long to keep TCP connections open for multiple requests.
- `gzip`: Enables HTTP compression to reduce bandwidth.
- `error_log` / `access_log`: Paths and formats for logging errors and access requests.
- `include`: Allows splitting configurations into mutliple smaller files for modularity. (`/etc/nginx/conf.d/*.conf`)

### Directives

1. Client Request Handling

|Directive|Description and Default|Guidance|
|--------|------------------------|--------|
|`client_max_body_size`|Limits max request body size. `1m`|Increase to `10m-50m` for JSON APIs, `100m+` for upload services.|
|`client_body_buffer_size`|In-memory buffer for request body before disk write. `8k` or `16k` for `64-bit`|`128k-512k` for JSON-heavy APIs to avoid temporary writes.|
|`client_header_buffer_size`|Buffer for request headers. `1k`| Increase to `2k-4k` for JWT or SSO heavy apps.|
|`large_client_header_buffers`|Number and size of large header buffers. `4 8k`| Set to `4 16k` or `8 32k` for large cookies or tokens.|
|`client_body_timeout`| Time to recieve client body. `60s`| Lower to `10s` to **prevent slowloris-type uploads**.|
|`client_header_timeout`|Time to recieve client header. `60s`| Set to `10-15s` for API gateways (defensively)|
|`keepalive_timeout`| Idle time for persistent connections. `75s`|`30-60s` for APIs, `10s` for Web frontends.|
|`send_timeout`| Timeout for client to read response. `60s`|`10-30s` for APIs.|
|`reset_timedout_connection`|Drop connections after timeout. `off`|Set to `on` in public facing APIs to clear sockets fast.|


2. Proxy and Upstream Settings

|Directive|Description and Default|Guidance|
|--------|------------------------|--------|
|`proxy_pass`|Defines upstream destination for requests.| Always use service names or load-balanced upstream blocks.|
|`proxy_set_header`|Passes client headers to upstreams.|Always include `Host`, `X-Real-IP`, `X-Forwarded-For`, `X-Request-ID`.|
|`proxy_connect_timeout`|Timeout for connecting to upstream. `60s`|`3-5s` for responsive services.|
|`proxy_send_timeout`|Timeout for sending request to upstream. `60s`|`10-30s` or shorter for APIs.|
|`proxy_read_timeout`|Timeout for reading response from upstream. `60s`|`30-60s` based on backend latency.|
|`proxy_buffering`| Enable/Disable response buffering. `on`| Keep `on` unless streaming. `off` is for WebSockets or gRPC|
|`proxy_buffers`|Number and size of buffers for response. `8 4k`| Increase to `8 16k` for large JSON payloads.|
|`proxy_busy_buffers_size`|How much of response can remain "in flight". `8k`|Set to `64k-128k` for high concurrency.|
|`proxy_temp_file_write_size`|Max temp file write size per write. `8k`|Increase if large responses spill to disk.|
|`proxy_next_upstream_tries`|Max number of retry attempts. `0 (unlimited)`|Limit to `2-3` for predictable behavior.|
|`proxy_http_version`| HTTP version used to communicate upstream. `1.0`| Use `1.1` for keepalive and chunked responses.|
|`proxy_set_header_Connection ""`|Prevents closing connections per request.|Use with keepalive upstreams for performance.|

3. Load Balancing and Upstream Pools

|Directive|Description and Default|Guidance|
|--------|------------------------|--------|
|`upstream {}`|Defines a pool of backend servers.|Always name pools clearly (user_service)|
|`least_conn` / `ip_hash` / `hash`|Load balancing methods. `round_robin`|`least_conn` for dynamic microservices. `ip_hash` for stickiness.|
|**`server` (inside `upstream`)**|Backend endpoint (`IP:port`)|Use FQDN for service discovery, mark with `max_fails` and `fail_timeout`.|
|`max_fails`|Failures before marking backend as down. `1`|Set to `3-5`|
|`fail_timeout`|Duration to consider backend unhealthy. `10s`|Increase to `30s` for slow backends.|
|`keepalive`|Number of idle connections to keep per worker. `none`|`16-64` for API heavy traffic to resuse TCP sessions.|
|**`zone` (NGINX Plus)**| Shared memory for dynamic upstreams.| Enables runtime reconfiguration.|

4. Output and Response Tuning

|Directive|Description and Default|Guidance|
|--------|------------------------|--------|
|`output_buffers`|Buffers for response body. `2 32k`|Keep `2-4 32k` for APIs, tune for memory.|
|`postpone_output`|Bytes to accumulate before flushing. `1460`|Keep `1-2` TCP segment size for efficiency.|
|`sendfile`|Use zero-copy file transfers. `off`|`on` for static content/large downloads.|
|`aio`|Enables async I/O. `off`|`on` for SSD-backend storage or large files.|
|`tcp_nopush`|Sends full packet (header and data). off|`on` with `sendfile` to optimize large responses.|
|`tcp_nodelay`| Disables Nagle's algorithm (allows small responses). `on`|Always `on` for low-latency APIs.|
|`gzip`| Enable compression. `off`|Enable for text/json, **disable for already-compressed data**.|
|`gzip_types`|MIME types for compression.|Add `application/json`, `application/javascript`, `text/css`.|
|`gzip_min_length`|Min size to compress. `20`| `1024` or higher to avoid overhead for small responses.|

5. Connection & Worker Tuning

|Directive|Description and Default|Guidance|
|--------|------------------------|--------|
|`worker_processes`|Number of OS-level workers. `1`| `auto` which is one per CPU core.|
|`worker_connections`|Max connections per worker. `1024`|`4096-8192` for API gateways.|
|`multi_accept`| Accept multiple connections per event. `off`|`on` for high concurrency.|
|`worker_rlimit_nofile`|Max file descriptors.|Match to `ulimit -n` (e.g. 65535)|
|`use epoll`| Event Method (Linux)| Always `epoll` for modern kernels.|
|`accept_mutex`|Prevent multiple workers from accepting at once. `on`|Keep `on` unless latency tuning.|

6. Security and Access Controls

|Directive|Description and Default|Guidance|
|--------|------------------------|--------|
|`ssl_protocols`|TLS versions to support. `TLSv1 TLSv1.1 TLSv1.2` |Use `TLSv1.2 TLSv1.3` only.|
|`ssl_ciphers`|Cipher suites allowed.|Use modern, secure sets.|
|`ssl_prefer_server_ciphers`| Prefer server's cipher order. `off`|`on` for compliance environments.|
|`ssl_session_cache`|Cache SSL sessions. `none`|`shared:SSL:10m` to reuse sessions.|
|`ssl_session_timeout`|Session cache lifetime. `5m`|`10m-30m` is typical.|
|`ssl_stapling`|Enables OCSP stapling. `off`|`on` for faster TLS handshakes.|
|`add_header`|Adds security headers.|Add `HSTS`, `CSP`, `X-Frame-Options`, etc.|
|`limit_req_zone` / `limit_req`|Rate limit per key/IP.|Essential for API abuse prevention.|
|`allow` / `deny`|Access control by IP.|Use for internal endpoints or admin panels.|

7. Logging and Monitoring

|Directive|Description and Default|Guidance|
|--------|------------------------|--------|
|`access_log`|Request logs. enabled|Use JSON or structured format for observability.|
|`error_log`|Error logs. stderr|Set to warn or error level in production.|
|`log_format`|Custom log fields.|Include $request_time, $upstream_response_time, $status, $remote_addr.|
|`stub_status`|Lightweight metrics endpoint.|Enable for prometheus exporter.|
|`status_zone` (Nginx Plus)|Tracks per-location metrics.|Useful for dashboards.|


8. Caching and Performance Enhancements

|Directive|Description and Default|Guidance|
|--------|------------------------|--------|
|`proxy_cache_path`|Defines cache storage location and zone.|Use SSD-backed storage, 1-10 GB per zone.|
|`proxy_cache`|Enables caching for location.| Cache GET responses where backend load is high.|
|`proxy_cache_valid`|TTL for cached responses.|`200 5m`, `404 1m` is typical.|
|`expires`|Adds Cache-Control headers.|Useful for static files.|
|`open_file_cache`|Caches open file descriptors. `off`|`open_file_cache max=1000 inactive=20s` for static files.|
|`open_file_cache_valid`| Revalidate cached file info. `60s`|Keep low for dynamic content.|


### Configuration Management

- Prior to reloading configuration, validate the new config syntax: `nginx -t`, to check for syntax errors without applying changes.
- To reload NGINX without downtime, apply the new changes with `nginx -s reload`. This starts new worker processes with the new configuration while allowing existing connections to complete.

- **DO NOT use systemctl** to restart nginx, as that will cause a brief service disruption.

## Architecture and Performance Strategies

### Worker Process Tuning

- nginx uses an asynchronous, event-driven architecture where the optimal worker configuration is similar to:

```t
# /etc/nginx/nginx.conf
user nginx;
worker_processes auto; # One per CPU core
worker_rlimit_nofile 65535; # Max file descriptors

events {
    worker_connections 4096; # Max connections per worker
    use epoll; # Linux optimization
    multi_accept on; # Accept multiple connections at once
}
```

- `Max Connections = worker_processes * worker_connections`


### Buffer Optimization

- Control how nginx buffers, reads, and writes data between client and backend (or filesystem).

```t
http {
    # Client body size
    client_body_buffer_size 128k; # temp store request body in memory before passed
    client_max_body_size 20m;
    client_header_buffer_size 1k;
    large_client_header_buffers 4 16k;

    # Output buffering
    output_buffers 2 32k;
    postpone_output 1460;

    # Timeouts
    client_body_timeout 12;
    client_header_timeout 12;
    keepalive_timeout 65;
    send_timeout 10;

    # TCP Optimization
    tcp_nopush on;
    tcp_nodelay on;
    sendfile on;
}
```

- **File Descriptors**: in NGINX, each active connection corresponds to at least one file descriptor, a positive integer that the kernel uses to keep track for open files, sockets, and other I/O resources.

```bash
# Check current limits
ulimit -n
# Set system wide limits in /etc/security/limits.conf
nginx soft nofile 65535
nginx hard nofile 65535
# Verify NGINX limit
cat /proc/$(cat /var/run/nginx.pid)/limits | grep "open files"
```

### Dynamic Upstream Configuration

```t
upstream backend_pool {
    zone backend_zone 64k;

    least_conn;

    server backend1.example.com:8080 weight=3 max_fails=3 fail_timeout=30s;
    server backend2.example.com:8080 weight=2;
    server backend1.example.com:8080 backup; # only used if others fail

    keepalive 32;
    keepalive_requests 100;
    keepalive_timeout 60s;
}

server {
    location /api {
        proxy_pass http://backend_pool; # Defined above in upstream
        proxy_http_version 1.1;
        proxy_set_header Connection "";

        # Preserve client information
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # Timeouts
        proxy_connect_timeout 5s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
        
        # Buffer configuration
        proxy_buffering on;
        proxy_buffer_size 4k;
        proxy_buffers 8 4k;
        proxy_busy_buffers_size 8k;
    }
}
```

### Advanced Rewrite Rules and Maps

- The `map` directive is used to create new variables whose values depend on source variables. It works like a conditional mapping or lookup table. Typically defined in **http context**.

```t
map $input_var $output_var {
    default <default value>;
    <match1> <result1>;
    <match2> <result2>;
}
```

- Supports regular expression with `~` or `~*`. Lazy evaluation, meaning it doesn't add overhead unless used.

- `geo` is used similar to map, but instead performs an IP-based lookup.

```t
# Define variable $mobile based on client User-Agent header
map $http_user_agent $mobile {
    default 0; # Default to 0 (not mobile) if no match
    ~*mobile 1
    ~*android 1;
    ~*iphone 1;
}

# Define $rate_limit_key based on URL requested
map $request_url $rate_limit_key {
    ~^/api/public/ "";
    default $binary_remote_addr; # Use client's binary address as the rate limiting key
}

# geographic routing
geo $geo_routing {
    default us-east;
    1.2.3.0/24 eu-west;
    4.5.6.0/24 ap-south;
}

server {
    # Conditional redirects
    # If mobile, redirect to mobile site
    if ($mobile) {
        rewrite ^ https://m.example.com$request_uri? redirect;
    }

    # Named location for internal routing
    location /process {
        error page 404 = @fallback # Redirect 404 errors internally to @fallback location
        proxy_pass http://primary_backend; # Should be defined in upstream
    }

    location @fallback {
        proxy_pass http://secondary_backend; # If fallback triggered, proxy to secondary backend
    }

    # Try files pattern
    location / {
        try_files $uri $uri/ @backend; # Try to serve files directly from filesystem
    }

    location @backend {
        proxy_pass http://backend_pool;
    }
}
```

### Request Rate Limiting

```t
# Define rate limit zones in http block
http {
    # IP based rate-limiting
    limit_req_zone $binary_remote_addr zone=per_ip:10m rate=10r/s;
    # API Key rate-limiting
    limit_req_zone $http_x_api_key zone=per_api_key:10m rate=100r/s;
    # Connection limiting
    limit_conn_zone $binary_remote_addr zone=conn_per_ip:10m;

    server {
        location /api/ {
            # Allow bursts but delay excess requests
            limit_req zone=per_ip burst=20 delay=10;
            # Limit concurrent connections
            limit_conn conn_per_ip 10;
            # Custom error responses
            limit_req_status 429;
            limit_conn_status 429;

            proxy_pass http://backend_pool;
        }

        # Whitelist certain IPs
        location /admin/ {
            limit_req zone=per_ip burst=5 nodelay;

            geo $limit {
                default 1;
                10.0.0.0/8 0; # Internal network
                192.168.1.100 0; # Admin IP
            }

            if ($limit) {
                return 403
            }

            proxy_pass http://admin_backend;
        }
    }
}
```

### Passive Health Checks

```t
upstream app_backend {
    # servers considered unavailable if failed 3 times in 30s
    server app1.example.com:8080 max_fails=3 fail_timeout=30s;
    server app2.example.com:8080 max_fails=3 fail_timeout=30s;
    # Check every request
    # Which types of error should trigger the next server
    proxy_next_upstream error timeout http_500 http_502 http_503 http_504;
    proxy_next_upstream_tries 2;
}
```

### Session Persistence

```t
# IP hash method
upstream sticky_backend { # Logical group of servers named sticky_backend
    ip_hash; # requests from same client IP will go to same backend
    server backend1.example.com:8080;
    server backend2.example.com:8080;
}

# Generic hash based on value of request uri (/products/123)
upstream uri_backend {
    hash $request_uri consistent; # Consistent hashing minimizes redistribution of traffic
    server backend1.example.com:8080;
    server backend2.example.com:8080;
}
```
