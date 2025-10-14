# Keycloak IAM Wiki - AWS EKS/ECS Java Applications

## What is Keycloak

**Keycloak** is an open-source IAM solution that provides authentication, authorization, and user management services for modern applications. It implements industry-standard protocols including OAuth 2.0, OpenID Connect (OIDC), and SAML 2.0, enabling SSO across multiple applications and services.

Built on top of the **Quarkus** framework (formerly **WildFly**), Keycloak offers enterprise-grade security features with minimal configuration overhead, making it ideal for microservices architectures and cloud-native deployments.

## Core Components

### 1. Realms

A **realm** is the fundamental organizational unit in Keycloak that manages a set of users, credentials, roles, and groups. Each realm is completely isolated from others, providing multi-tenancy capabilities.

```
Example Structure:
├── master (administrative realm)
├── company-realm
│   ├── users (employees)
│   ├── clients (applications)
│   └── roles (permissions)
└── customer-realm
    ├── users (customers)
    ├── clients (customer apps)
    └── roles (customer permissions)
```

**Key Features:**
- Complete isolation between realms
- Independent user bases and authentication policies
- Separate token signing keys per realm
- Realm-specific themes and customizations

### 2. Users

Users represent individuals who authenticate against Keycloak. Each user belongs to exactly one realm and contains:

- **Basic attributes**: username, email, first/last name
- **Credentials**: passwords, OTP tokens, certificates
- **Sessions**: active login sessions across applications
- **Consents**: granted permissions to applications
- **Role mappings**: assigned roles and permissions

**User Storage Options:**
- **Local storage**: Users stored in Keycloak's database
- **User Federation**: LDAP/Active Directory integration
- **Custom providers**: External user stores via SPI

### 3. Clients

A **client** represents an application that can request authentication from Keycloak. Clients define how applications interact with the authentication server.

**Client Types:**

**Public Clients** (Frontend applications):
```json
{
  "clientId": "spa-app",
  "publicClient": true,
  "standardFlowEnabled": true,
  "implicitFlowEnabled": false,
  "directAccessGrantsEnabled": false,
  "redirectUris": ["https://app.example.com/*"],
  "webOrigins": ["https://app.example.com"]
}
```

**Confidential Clients** (Backend services):
```json
{
  "clientId": "backend-service",
  "publicClient": false,
  "bearerOnly": true,
  "serviceAccountsEnabled": true,
  "authorizationServicesEnabled": true
}
```

**Bearer-only Clients** (Resource servers):
```json
{
  "clientId": "api-gateway",
  "bearerOnly": true,
  "protocol": "openid-connect"
}
```

### 4. Roles

Roles define permissions and access levels within the system. Keycloak supports two types of roles:

**Realm Roles** (Global to the realm):
```
ADMIN - Full administrative access
USER - Standard user access
MODERATOR - Content moderation rights
```

**Client Roles** (Specific to an application):
```
spa-app roles:
├── VIEW_DASHBOARD
├── EDIT_PROFILE
└── SUBMIT_ORDERS

backend-service roles:
├── READ_USERS
├── WRITE_USERS
└── DELETE_USERS
```

**Role Composition**:
```
ADMIN (composite role)
├── USER (base role)
├── MODERATOR (base role)
└── SYSTEM_ADMIN (base role)
```

### 5. Groups

Groups provide hierarchical organization of users and roles, enabling easier management of large user bases.

```
Organization Structure:
├── Engineering
│   ├── Frontend Team
│   │   ├── Senior Developers (roles: ADMIN, DEPLOY)
│   │   └── Junior Developers (roles: USER, CODE_REVIEW)
│   └── Backend Team
│       ├── API Developers (roles: API_ADMIN, DATABASE_ACCESS)
│       └── DevOps Engineers (roles: INFRASTRUCTURE, MONITORING)
└── Sales
    ├── Account Managers (roles: CRM_ACCESS, CUSTOMER_DATA)
    └── Sales Representatives (roles: LEAD_ACCESS, BASIC_CRM)
```

**Group Benefits:**
- Inherit roles from parent groups
- Dynamic role assignment based on group membership
- Simplified user management for large organizations
- Support for nested group hierarchies

### 6. Identity Providers

Identity providers enable federation with external authentication systems, allowing users to authenticate using existing credentials.

**Supported Protocols:**
- **OpenID Connect**: Google, Microsoft Azure AD, GitHub
- **SAML**: Corporate SAML providers, ADFS
- **Social**: Facebook, Twitter, LinkedIn
- **Custom**: Via SPI implementation

**Configuration Example** (Google OIDC):
```json
{
  "alias": "google",
  "providerId": "oidc",
  "enabled": true,
  "config": {
    "clientId": "google-client-id",
    "clientSecret": "google-client-secret",
    "issuer": "https://accounts.google.com",
    "defaultScope": "openid profile email"
  }
}
```

### 7. Protocol Mappers

Protocol mappers transform user data into tokens and assertions, controlling what information is included in authentication responses.

**Common Mapper Types:**

**User Attribute Mapper**:
```json
{
  "name": "department-mapper",
  "protocol": "openid-connect",
  "protocolMapper": "oidc-usermodel-attribute-mapper",
  "config": {
    "user.attribute": "department",
    "claim.name": "department",
    "jsonType.label": "String",
    "id.token.claim": "true",
    "access.token.claim": "true"
  }
}
```

**Role List Mapper**:
```json
{
  "name": "realm-roles",
  "protocol": "openid-connect", 
  "protocolMapper": "oidc-usermodel-realm-role-mapper",
  "config": {
    "claim.name": "realm_access.roles",
    "jsonType.label": "String",
    "multivalued": "true"
  }
}
```

**Group Membership Mapper**:
```json
{
  "name": "groups",
  "protocol": "openid-connect",
  "protocolMapper": "oidc-group-membership-mapper",
  "config": {
    "claim.name": "groups",
    "full.path": "false",
    "id.token.claim": "true",
    "access.token.claim": "true"
  }
}
```

## Authentication Flows

### 1. Authorization Code Flow (Standard Flow)

Primary flow for web applications with server-side components:

```
┌─────────┐    1. Login Request     ┌─────────────┐
│ Browser │ ────────────────────────▶│  Keycloak   │
└─────────┘                         └─────────────┘
     │                                      │
     │    2. Auth Code                      │
     │ ◀────────────────────────────────────┤
     │                                      │
     ▼         3. Code + Credentials        ▼
┌─────────┐ ────────────────────────▶┌─────────────┐
│   App   │                         │  Keycloak   │
│ Server  │ ◀────────────────────────│   Token     │
└─────────┘    4. Access Token      │  Endpoint   │
                                    └─────────────┘
```

**Configuration**:
```json
{
  "standardFlowEnabled": true,
  "implicitFlowEnabled": false,
  "directAccessGrantsEnabled": false,
  "serviceAccountsEnabled": false
}
```

### 2. Implicit Flow (Deprecated)

Legacy flow for SPAs, now superseded by Authorization Code + PKCE:

```json
{
  "implicitFlowEnabled": true,
  "standardFlowEnabled": false
}
```

### 3. Resource Owner Password Credentials (Direct Access)

For trusted applications only:

```json
{
  "directAccessGrantsEnabled": true,
  "standardFlowEnabled": false
}
```

### 4. Client Credentials Flow

For service-to-service authentication:

```json
{
  "serviceAccountsEnabled": true,
  "publicClient": false,
  "bearerOnly": false
}
```

## Token Types

### Access Tokens

Short-lived tokens (5-15 minutes) containing user identity and permissions:

```json
{
  "exp": 1640995200,
  "iat": 1640994300,
  "iss": "https://auth.example.com/realms/myapp",
  "aud": "backend-service",
  "sub": "user-123",
  "typ": "Bearer",
  "azp": "spa-app",
  "session_state": "session-456",
  "realm_access": {
    "roles": ["USER", "MODERATOR"]
  },
  "resource_access": {
    "backend-service": {
      "roles": ["READ_DATA", "WRITE_DATA"]
    }
  },
  "scope": "openid profile email",
  "email": "user@example.com",
  "preferred_username": "user123",
  "groups": ["/Engineering/Backend Team"]
}
```

### Refresh Tokens

Long-lived tokens (30 minutes to days) used to obtain new access tokens:

```json
{
  "exp": 1641081600,
  "iat": 1640994300,
  "iss": "https://auth.example.com/realms/myapp",
  "aud": "https://auth.example.com/realms/myapp",
  "sub": "user-123",
  "typ": "Refresh",
  "azp": "spa-app",
  "session_state": "session-456",
  "scope": "openid profile email offline_access"
}
```

### ID Tokens

OpenID Connect tokens containing user identity information:

```json
{
  "exp": 1640995200,
  "iat": 1640994300,
  "iss": "https://auth.example.com/realms/myapp",
  "aud": "spa-app",
  "sub": "user-123",
  "typ": "ID",
  "azp": "spa-app",
  "session_state": "session-456",
  "at_hash": "hash-value",
  "email": "user@example.com",
  "email_verified": true,
  "preferred_username": "user123",
  "given_name": "John",
  "family_name": "Doe",
  "picture": "https://example.com/avatar.jpg"
}
```

## Session Management

### Session Types

**User Sessions**:
- Browser-based authentication sessions
- Tied to specific realm and client
- Can span multiple applications (SSO)
- Configurable idle and maximum timeouts

**Offline Sessions**:
- Long-term sessions for mobile/desktop apps
- Survive browser closures and restarts
- Require `offline_access` scope

**Client Sessions**:
- Per-application session state
- Tracks which clients user has authenticated to
- Enables selective logout per application

### Session Configuration

```json
{
  "ssoSessionIdleTimeout": 1800,
  "ssoSessionMaxLifespan": 36000,
  "ssoSessionIdleTimeoutRememberMe": 0,
  "ssoSessionMaxLifespanRememberMe": 0,
  "offlineSessionIdleTimeout": 2592000,
  "offlineSessionMaxLifespanEnabled": false,
  "clientSessionIdleTimeout": 0,
  "clientSessionMaxLifespan": 0
}
```

## Admin Console Structure

### Master Realm
- Global administrative realm
- Manages other realms
- Contains admin users
- Should be secured and access-restricted

### Realm Management
- User management and import/export
- Client configuration and secrets
- Role and group administration
- Identity provider setup
- Theme customization

### Monitoring and Events
- Login/logout events
- Admin actions audit trail
- Failed authentication tracking
- Custom event listeners

## Security Features

### Brute Force Protection

```json
{
  "bruteForceProtected": true,
  "permanentLockout": false,
  "maxFailureWaitSeconds": 900,
  "minimumQuickLoginWaitSeconds": 60,
  "waitIncrementSeconds": 60,
  "quickLoginCheckMilliSeconds": 1000,
  "maxDeltaTimeSeconds": 43200,
  "failureFactor": 30
}
```

### Password Policies

```json
{
  "passwordPolicy": "length(8) and digits(2) and lowerCase(2) and upperCase(2) and specialChars(1) and notUsername and notEmail and hashIterations(27500)"
}
```

### Required Actions

User-required actions for security compliance:
- Update password
- Configure OTP
- Verify email
- Update profile
- Terms and conditions

### Multi-Factor Authentication

**Built-in Authenticators**:
- TOTP (Google Authenticator, Authy)
- SMS via custom SPI
- Email verification
- WebAuthn/FIDO2
- Backup codes

**Configuration Example**:
```json
{
  "requiredActions": [
    {
      "alias": "CONFIGURE_TOTP",
      "name": "Configure OTP",
      "enabled": true,
      "defaultAction": true
    }
  ]
}
```

## High-Level Integration Patterns

### 1. API Gateway Pattern

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   Client    │───▶│ API Gateway │───▶│ Microservice│
│     App     │    │ (Kong/Envoy)│    │  (Java)     │
└─────────────┘    └─────────────┘    └─────────────┘
                          │
                          ▼
                   ┌─────────────┐
                   │  Keycloak   │
                   │    OIDC     │
                   └─────────────┘
```

### 2. Service Mesh Pattern

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   Client    │───▶│   Istio     │───▶│ Service A   │
│     App     │    │   Proxy     │    │   (Java)    │
└─────────────┘    └─────────────┘    └─────────────┘
                          │                   │
                          │                   ▼
                          │            ┌─────────────┐
                          │            │ Service B   │
                          │            │   (Java)    │
                          │            └─────────────┘
                          ▼
                   ┌─────────────┐
                   │  Keycloak   │
                   │   JWT       │
                   └─────────────┘
```

### 3. Backend for Frontend (BFF) Pattern

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   SPA       │───▶│    BFF      │───▶│ Backend API │
│  (React)    │    │  (Node.js)  │    │   (Java)    │
└─────────────┘    └─────────────┘    └─────────────┘
                          │
                          ▼
                   ┌─────────────┐
                   │  Keycloak   │
                   │  Auth Code  │
                   └─────────────┘
```

## Scalability Considerations

### Clustering

Keycloak supports clustering for high availability and load distribution:

**Database Sharing**: All nodes share the same database
**Infinispan Caching**: Distributed cache across cluster nodes
**Load Balancing**: Sticky sessions not required for most operations

### Performance Tuning

**Database Optimization**:
- Connection pooling configuration
- Proper indexing on user tables
- Regular maintenance and cleanup

**JVM Tuning**:
- Heap size optimization
- Garbage collection tuning
- Connection pool sizing

**Caching Strategy**:
- User cache configuration
- Realm and client caching
- External cache providers (Redis)

This overview provides the foundation for understanding Keycloak's architecture and capabilities before diving into the specific AWS EKS/ECS implementation details covered in the main wiki sections.
## Architecture Overview

Keycloak serves as the central Identity and Access Management (IAM) provider for Java applications deployed on AWS EKS and ECS. The architecture follows OAuth 2.0/OpenID Connect standards with RBAC integration.

```txt
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Client Apps   │───▶│    Keycloak      │───▶│  Java Backend   │
│   (React/Vue)   │    │   (Auth Server)  │    │   (EKS/ECS)     │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                              │
                              ▼
                       ┌──────────────────┐
                       │   PostgreSQL     │
                       │   (RDS/Aurora)   │
                       └──────────────────┘
```

## EKS Deployment

### Keycloak Deployment Manifest

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: keycloak
  namespace: auth
spec:
  replicas: 2
  selector:
    matchLabels:
      app: keycloak
  template:
    metadata:
      labels:
        app: keycloak
    spec:
      containers:
      - name: keycloak
        image: quay.io/keycloak/keycloak:22.0
        args: ["start", "--optimized"]
        env:
        - name: KEYCLOAK_ADMIN
          value: "admin"
        - name: KEYCLOAK_ADMIN_PASSWORD
          valueFrom:
            secretKeyRef:
              name: keycloak-secret
              key: admin-password
        - name: KC_DB
          value: "postgres"
        - name: KC_DB_URL
          value: "jdbc:postgresql://keycloak-db.cluster-xxx.us-west-2.rds.amazonaws.com:5432/keycloak"
        - name: KC_DB_USERNAME
          valueFrom:
            secretKeyRef:
              name: db-secret
              key: username
        - name: KC_DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: db-secret
              key: password
        - name: KC_HOSTNAME
          value: "auth.example.com"
        - name: KC_PROXY
          value: "edge"
        - name: KC_HEALTH_ENABLED
          value: "true"
        - name: KC_METRICS_ENABLED
          value: "true"
        ports:
        - containerPort: 8080
        - containerPort: 9000
        readinessProbe:
          httpGet:
            path: /realms/master
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
        livenessProbe:
          httpGet:
            path: /health/live
            port: 9000
          initialDelaySeconds: 60
          periodSeconds: 30
        resources:
          requests:
            memory: "1Gi"
            cpu: "500m"
          limits:
            memory: "2Gi"
            cpu: "1000m"
---
apiVersion: v1
kind: Service
metadata:
  name: keycloak-service
  namespace: auth
spec:
  selector:
    app: keycloak
  ports:
  - name: http
    port: 8080
    targetPort: 8080
  - name: metrics
    port: 9000
    targetPort: 9000
  type: ClusterIP
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: keycloak-ingress
  namespace: auth
  annotations:
    kubernetes.io/ingress.class: "alb"
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/certificate-arn: "arn:aws:acm:us-west-2:123456789012:certificate/xxx"
    alb.ingress.kubernetes.io/ssl-policy: ELBSecurityPolicy-TLS-1-2-2017-01
spec:
  rules:
  - host: auth.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: keycloak-service
            port:
              number: 8080
```

### Java Application Deployment with OIDC

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: java-app
  namespace: default
spec:
  replicas: 3
  selector:
    matchLabels:
      app: java-app
  template:
    metadata:
      labels:
        app: java-app
    spec:
      containers:
      - name: java-app
        image: myregistry/java-app:latest
        env:
        - name: SPRING_SECURITY_OAUTH2_RESOURCESERVER_JWT_ISSUER_URI
          value: "https://auth.example.com/realms/myapp"
        - name: SPRING_SECURITY_OAUTH2_RESOURCESERVER_JWT_JWK_SET_URI
          value: "https://auth.example.com/realms/myapp/protocol/openid-connect/certs"
        - name: KEYCLOAK_AUTH_SERVER_URL
          value: "https://auth.example.com"
        - name: KEYCLOAK_REALM
          value: "myapp"
        - name: KEYCLOAK_RESOURCE
          value: "java-backend"
        ports:
        - containerPort: 8080
        readinessProbe:
          httpGet:
            path: /actuator/health
            port: 8080
          initialDelaySeconds: 30
        resources:
          requests:
            memory: "512Mi"
            cpu: "250m"
          limits:
            memory: "1Gi"
            cpu: "500m"
```

## ECS Deployment

### Task Definition

```json
{
  "family": "keycloak-task",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "1024",
  "memory": "2048",
  "executionRoleArn": "arn:aws:iam::123456789012:role/ecsTaskExecutionRole",
  "taskRoleArn": "arn:aws:iam::123456789012:role/keycloakTaskRole",
  "containerDefinitions": [
    {
      "name": "keycloak",
      "image": "quay.io/keycloak/keycloak:22.0",
      "command": ["start", "--optimized"],
      "portMappings": [
        {
          "containerPort": 8080,
          "protocol": "tcp"
        }
      ],
      "environment": [
        {
          "name": "KC_DB",
          "value": "postgres"
        },
        {
          "name": "KC_DB_URL",
          "value": "jdbc:postgresql://keycloak-db.cluster-xxx.us-west-2.rds.amazonaws.com:5432/keycloak"
        },
        {
          "name": "KC_HOSTNAME",
          "value": "auth.example.com"
        },
        {
          "name": "KC_PROXY",
          "value": "edge"
        }
      ],
      "secrets": [
        {
          "name": "KEYCLOAK_ADMIN_PASSWORD",
          "valueFrom": "arn:aws:secretsmanager:us-west-2:123456789012:secret:keycloak/admin-xxx"
        },
        {
          "name": "KC_DB_USERNAME",
          "valueFrom": "arn:aws:secretsmanager:us-west-2:123456789012:secret:keycloak/db-username-xxx"
        },
        {
          "name": "KC_DB_PASSWORD",
          "valueFrom": "arn:aws:secretsmanager:us-west-2:123456789012:secret:keycloak/db-password-xxx"
        }
      ],
      "healthCheck": {
        "command": [
          "CMD-SHELL",
          "curl -f http://localhost:8080/realms/master || exit 1"
        ],
        "interval": 30,
        "timeout": 5,
        "retries": 3,
        "startPeriod": 60
      },
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/keycloak",
          "awslogs-region": "us-west-2",
          "awslogs-stream-prefix": "ecs"
        }
      }
    }
  ]
}
```

### Service Configuration

```json
{
  "serviceName": "keycloak-service",
  "cluster": "keycloak-cluster",
  "taskDefinition": "keycloak-task",
  "desiredCount": 2,
  "launchType": "FARGATE",
  "networkConfiguration": {
    "awsvpcConfiguration": {
      "subnets": [
        "subnet-12345678",
        "subnet-87654321"
      ],
      "securityGroups": [
        "sg-keycloak123"
      ],
      "assignPublicIp": "DISABLED"
    }
  },
  "loadBalancers": [
    {
      "targetGroupArn": "arn:aws:elasticloadbalancing:us-west-2:123456789012:targetgroup/keycloak-tg/xxx",
      "containerName": "keycloak",
      "containerPort": 8080
    }
  ]
}
```

## Spring Boot Integration

### Dependencies (pom.xml)

```xml
<dependencies>
    <dependency>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-oauth2-resource-server</artifactId>
    </dependency>
    <dependency>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-oauth2-client</artifactId>
    </dependency>
    <dependency>
        <groupId>org.keycloak</groupId>
        <artifactId>keycloak-spring-boot-starter</artifactId>
        <version>22.0.1</version>
    </dependency>
</dependencies>
```

### Security Configuration

```java
@Configuration
@EnableWebSecurity
@EnableMethodSecurity(prePostEnabled = true)
public class SecurityConfig {

    @Value("${spring.security.oauth2.resourceserver.jwt.issuer-uri}")
    private String issuerUri;

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http
            .sessionManagement(session -> session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
            .csrf(csrf -> csrf.disable())
            .authorizeHttpRequests(authz -> authz
                .requestMatchers("/actuator/health", "/api/public/**").permitAll()
                .requestMatchers("/api/admin/**").hasRole("ADMIN")
                .requestMatchers("/api/user/**").hasAnyRole("USER", "ADMIN")
                .anyRequest().authenticated()
            )
            .oauth2ResourceServer(oauth2 -> oauth2
                .jwt(jwt -> jwt
                    .jwtAuthenticationConverter(jwtAuthenticationConverter())
                    .decoder(jwtDecoder())
                )
            );
        return http.build();
    }

    @Bean
    public JwtDecoder jwtDecoder() {
        return JwtDecoders.fromIssuerLocation(issuerUri);
    }

    @Bean
    public JwtAuthenticationConverter jwtAuthenticationConverter() {
        JwtAuthenticationConverter converter = new JwtAuthenticationConverter();
        converter.setJwtGrantedAuthoritiesConverter(jwt -> {
            Collection<String> authorities = new ArrayList<>();
            
            // Extract realm roles
            Map<String, Object> realmAccess = jwt.getClaim("realm_access");
            if (realmAccess != null && realmAccess.containsKey("roles")) {
                Collection<String> realmRoles = (Collection<String>) realmAccess.get("roles");
                authorities.addAll(realmRoles.stream()
                    .map(role -> "ROLE_" + role.toUpperCase())
                    .collect(Collectors.toList()));
            }

            // Extract resource roles
            Map<String, Object> resourceAccess = jwt.getClaim("resource_access");
            if (resourceAccess != null) {
                String clientId = "java-backend"; // Your client ID
                Map<String, Object> clientAccess = (Map<String, Object>) resourceAccess.get(clientId);
                if (clientAccess != null && clientAccess.containsKey("roles")) {
                    Collection<String> clientRoles = (Collection<String>) clientAccess.get("roles");
                    authorities.addAll(clientRoles.stream()
                        .map(role -> "ROLE_" + role.toUpperCase())
                        .collect(Collectors.toList()));
                }
            }

            return authorities.stream()
                .map(SimpleGrantedAuthority::new)
                .collect(Collectors.toList());
        });
        return converter;
    }
}
```

### Application Properties

```yaml
spring:
  security:
    oauth2:
      resourceserver:
        jwt:
          issuer-uri: https://auth.example.com/realms/myapp
          jwk-set-uri: https://auth.example.com/realms/myapp/protocol/openid-connect/certs

keycloak:
  auth-server-url: https://auth.example.com
  realm: myapp
  resource: java-backend
  public-client: false
  bearer-only: true
  ssl-required: external

logging:
  level:
    org.springframework.security: DEBUG
    org.keycloak: DEBUG

management:
  endpoints:
    web:
      exposure:
        include: health,info,metrics
  endpoint:
    health:
      show-details: when-authorized
```

### REST Controller Example

```java
@RestController
@RequestMapping("/api")
@Validated
public class UserController {

    @GetMapping("/user/profile")
    @PreAuthorize("hasRole('USER')")
    public ResponseEntity<UserProfile> getUserProfile(Authentication authentication) {
        JwtAuthenticationToken jwt = (JwtAuthenticationToken) authentication;
        String userId = jwt.getToken().getSubject();
        String username = jwt.getToken().getClaim("preferred_username");
        String email = jwt.getToken().getClaim("email");
        
        UserProfile profile = UserProfile.builder()
            .id(userId)
            .username(username)
            .email(email)
            .roles(authentication.getAuthorities().stream()
                .map(GrantedAuthority::getAuthority)
                .collect(Collectors.toList()))
            .build();
            
        return ResponseEntity.ok(profile);
    }

    @GetMapping("/admin/users")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<List<UserProfile>> getAllUsers() {
        // Admin-only endpoint
        return ResponseEntity.ok(userService.getAllUsers());
    }

    @PostMapping("/user/data")
    @PreAuthorize("hasRole('USER') and @securityService.canAccessUserData(authentication, #userId)")
    public ResponseEntity<Void> updateUserData(@RequestParam String userId, @RequestBody UserData data) {
        userService.updateUserData(userId, data);
        return ResponseEntity.ok().build();
    }
}
```

### Security Service for Custom Authorization

```java
@Service
public class SecurityService {

    public boolean canAccessUserData(Authentication authentication, String userId) {
        JwtAuthenticationToken jwt = (JwtAuthenticationToken) authentication;
        String tokenUserId = jwt.getToken().getSubject();
        
        // Users can only access their own data unless they're admin
        return tokenUserId.equals(userId) || 
               authentication.getAuthorities().stream()
                   .anyMatch(auth -> auth.getAuthority().equals("ROLE_ADMIN"));
    }

    public boolean hasCustomPermission(Authentication authentication, String resource, String action) {
        JwtAuthenticationToken jwt = (JwtAuthenticationToken) authentication;
        Map<String, Object> authorization = jwt.getToken().getClaim("authorization");
        
        if (authorization != null && authorization.containsKey("permissions")) {
            List<Map<String, Object>> permissions = (List<Map<String, Object>>) authorization.get("permissions");
            return permissions.stream()
                .anyMatch(perm -> resource.equals(perm.get("rsname")) && 
                                ((List<String>) perm.get("scopes")).contains(action));
        }
        
        return false;
    }
}
```

## Keycloak Configuration

### Realm Configuration (JSON Export)

```json
{
  "realm": "myapp",
  "enabled": true,
  "accessTokenLifespan": 300,
  "ssoSessionIdleTimeout": 1800,
  "ssoSessionMaxLifespan": 36000,
  "offlineSessionIdleTimeout": 2592000,
  "accessCodeLifespan": 60,
  "accessCodeLifespanUserAction": 300,
  "roles": {
    "realm": [
      {
        "name": "USER",
        "description": "Standard user role"
      },
      {
        "name": "ADMIN", 
        "description": "Administrator role"
      }
    ]
  },
  "clients": [
    {
      "clientId": "java-backend",
      "enabled": true,
      "bearerOnly": true,
      "protocol": "openid-connect",
      "attributes": {
        "access.token.lifespan": "300"
      },
      "protocolMappers": [
        {
          "name": "realm-roles",
          "protocol": "openid-connect",
          "protocolMapper": "oidc-usermodel-realm-role-mapper",
          "config": {
            "claim.name": "realm_access.roles",
            "jsonType.label": "String",
            "multivalued": "true"
          }
        }
      ]
    },
    {
      "clientId": "frontend-app",
      "enabled": true,
      "publicClient": true,
      "protocol": "openid-connect",
      "redirectUris": ["http://localhost:3000/*", "https://app.example.com/*"],
      "webOrigins": ["http://localhost:3000", "https://app.example.com"],
      "standardFlowEnabled": true,
      "implicitFlowEnabled": false,
      "directAccessGrantsEnabled": false
    }
  ]
}
```

### Custom SPI Provider Example

```java
@Component
public class CustomUserStorageProvider implements UserStorageProvider {

    @Override
    public UserModel getUserById(String id, RealmModel realm) {
        // Custom user lookup logic
        return findUserInExternalSystem(id);
    }

    @Override
    public UserModel getUserByUsername(String username, RealmModel realm) {
        // Username-based lookup
        return findUserByUsername(username);
    }

    @Override
    public UserModel getUserByEmail(String email, RealmModel realm) {
        // Email-based lookup
        return findUserByEmail(email);
    }

    @Override
    public boolean isValid(RealmModel realm, UserModel user) {
        // Validate user is still active
        return validateUser(user);
    }

    @Override
    public void close() {
        // Cleanup resources
    }
}
```

## AWS IAM Integration

### IAM Role for EKS Service Account

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: keycloak-sa
  namespace: auth
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::123456789012:role/keycloak-irsa-role
---
# IAM Trust Policy
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::123456789012:oidc-provider/oidc.eks.us-west-2.amazonaws.com/id/EXAMPLED539D4633E53DE1B716D3041E"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "oidc.eks.us-west-2.amazonaws.com/id/EXAMPLED539D4633E53DE1B716D3041E:sub": "system:serviceaccount:auth:keycloak-sa",
          "oidc.eks.us-west-2.amazonaws.com/id/EXAMPLED539D4633E53DE1B716D3041E:aud": "sts.amazonaws.com"
        }
      }
    }
  ]
}
```

### IAM Policy for Secrets Manager Access

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret"
      ],
      "Resource": [
        "arn:aws:secretsmanager:us-west-2:123456789012:secret:keycloak/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "rds:DescribeDBInstances",
        "rds:DescribeDBClusters"
      ],
      "Resource": "*"
    }
  ]
}
```

## Monitoring and Observability

### Prometheus Metrics Configuration

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-config
data:
  prometheus.yml: |
    global:
      scrape_interval: 15s
    scrape_configs:
    - job_name: 'keycloak'
      static_configs:
      - targets: ['keycloak-service:9000']
      metrics_path: '/metrics'
      scrape_interval: 30s
    - job_name: 'java-apps'
      kubernetes_sd_configs:
      - role: endpoints
        namespaces:
          names:
          - default
      relabel_configs:
      - source_labels: [__meta_kubernetes_service_annotation_prometheus_io_scrape]
        action: keep
        regex: true
```

### Grafana Dashboard Query Examples

```promql
# Keycloak login rate
rate(keycloak_logins_total[5m])

# Failed login attempts
rate(keycloak_login_errors_total[5m])

# Active sessions
keycloak_user_sessions_total

# JWT token validation latency
histogram_quantile(0.95, rate(spring_security_authentication_duration_bucket[5m]))

# Application response time
histogram_quantile(0.95, rate(http_server_requests_duration_seconds_bucket{uri!~"/actuator.*"}[5m]))
```

## Production Best Practices

### High Availability Setup

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: keycloak-ha
spec:
  replicas: 3
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1
      maxSurge: 1
  template:
    spec:
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchExpressions:
                - key: app
                  operator: In
                  values:
                  - keycloak
              topologyKey: kubernetes.io/hostname
      containers:
      - name: keycloak
        env:
        - name: KC_CACHE
          value: "ispn"
        - name: KC_CACHE_STACK
          value: "kubernetes"
        - name: JGROUPS_DISCOVERY_PROTOCOL
          value: "kubernetes.KUBE_PING"
        - name: JGROUPS_DISCOVERY_PROPERTIES
          value: "port_range=0,dump_requests=true"
        - name: KC_TRANSACTION_XA_ENABLED
          value: "false"
```

### Database Connection Pooling

```yaml
env:
- name: KC_DB_POOL_INITIAL_SIZE
  value: "5"
- name: KC_DB_POOL_MIN_SIZE
  value: "5"
- name: KC_DB_POOL_MAX_SIZE
  value: "20"
- name: KC_DB_POOL_MAX_LIFETIME
  value: "300000"
```

### Security Headers Configuration

```java
@Configuration
public class SecurityHeadersConfig {
    
    @Bean
    public FilterRegistrationBean<SecurityHeadersFilter> securityHeadersFilter() {
        FilterRegistrationBean<SecurityHeadersFilter> registration = new FilterRegistrationBean<>();
        registration.setFilter(new SecurityHeadersFilter());
        registration.addUrlPatterns("/*");
        registration.setOrder(1);
        return registration;
    }
}

public class SecurityHeadersFilter implements Filter {
    
    @Override
    public void doFilter(ServletRequest request, ServletResponse response, FilterChain chain) 
            throws IOException, ServletException {
        HttpServletResponse httpResponse = (HttpServletResponse) response;
        
        httpResponse.setHeader("X-Content-Type-Options", "nosniff");
        httpResponse.setHeader("X-Frame-Options", "DENY");
        httpResponse.setHeader("X-XSS-Protection", "1; mode=block");
        httpResponse.setHeader("Strict-Transport-Security", "max-age=31536000; includeSubDomains");
        httpResponse.setHeader("Content-Security-Policy", "default-src 'self'");
        
        chain.doFilter(request, response);
    }
}
```

## Troubleshooting

### Common Issues and Solutions

**JWT Token Validation Failures:**
```bash
# Check issuer URI accessibility
curl -k https://auth.example.com/realms/myapp/.well-known/openid_configuration

# Verify JWT format
echo "eyJ..." | base64 -d | jq

# Check clock synchronization
timedatectl status
```

**Database Connection Issues:**
```sql
-- Check active connections
SELECT count(*) FROM pg_stat_activity WHERE datname = 'keycloak';

-- Monitor connection pool
SELECT * FROM pg_stat_database WHERE datname = 'keycloak';
```

**Performance Tuning:**
```bash
# JVM heap sizing
-Xms1024m -Xmx2048m -XX:MetaspaceSize=96M -XX:MaxMetaspaceSize=256m

# GC tuning
-XX:+UseG1GC -XX:MaxGCPauseMillis=200 -XX:ParallelGCThreads=4
```

### Debug Logging Configuration

```yaml
env:
- name: KC_LOG_LEVEL
  value: "DEBUG"
- name: QUARKUS_LOG_CATEGORY_ORG_KEYCLOAK_LEVEL
  value: "DEBUG"
- name: QUARKUS_LOG_CATEGORY_ORG_KEYCLOAK_SERVICES_LEVEL
  value: "TRACE"
```