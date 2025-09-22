# Multi-stage Dockerfile for Java microservices
FROM eclipse-temurin:21-jdk-alpine AS builder

# Install dependencies for building
RUN apk add --no-cache curl tar bash

# Set up Maven
ARG MAVEN_VERSION=3.9.6
RUN mkdir -p /usr/share/maven /usr/share/maven/ref && \
    curl -fsSL -o /tmp/apache-maven.tar.gz \
    https://archive.apache.org/dist/maven/maven-3/${MAVEN_VERSION}/binaries/apache-maven-${MAVEN_VERSION}-bin.tar.gz && \
    tar -xzf /tmp/apache-maven.tar.gz -C /usr/share/maven --strip-components=1 && \
    rm -f /tmp/apache-maven.tar.gz && \
    ln -s /usr/share/maven/bin/mvn /usr/bin/mvn

# Copy source code
WORKDIR /app
COPY pom.xml .
COPY src ./src

# Build application
RUN mvn clean package -DskipTests

# Runtime stage
FROM eclipse-temurin:21-jre-alpine

# Build arguments
ARG BUILD_DATE
ARG VCS_REF
ARG VERSION

# Labels for metadata
LABEL org.label-schema.build-date=$BUILD_DATE \
      org.label-schema.name="microservice-app" \
      org.label-schema.description="Java microservice application" \
      org.label-schema.url="https://company.com" \
      org.label-schema.vcs-ref=$VCS_REF \
      org.label-schema.vcs-url="https://github.com/company/microservice-app" \
      org.label-schema.vendor="Company Name" \
      org.label-schema.version=$VERSION \
      org.label-schema.schema-version="1.0"

# Install runtime dependencies
RUN apk add --no-cache \
    curl \
    dumb-init \
    && rm -rf /var/cache/apk/*

# Create application user
RUN addgroup -g 1000 appuser && \
    adduser -D -u 1000 -G appuser appuser

# Create application directories
RUN mkdir -p /app /var/log/microservice-app && \
    chown -R appuser:appuser /app /var/log/microservice-app

# Switch to application user
USER appuser

# Copy application jar
COPY --from=builder --chown=appuser:appuser /app/target/*.jar /app/app.jar

# Set working directory
WORKDIR /app

# Expose ports
EXPOSE 8080 8081

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8081/actuator/health || exit 1

# JVM configuration
ENV JAVA_OPTS="-XX:+UseContainerSupport \
               -XX:MaxRAMPercentage=75.0 \
               -XX:+UseG1GC \
               -XX:+PrintGC \
               -XX:+PrintGCTimeStamps \
               -Xlog:gc*:gc.log \
               -XX:+ExitOnOutOfMemoryError \
               -XX:+CrashOnOutOfMemoryError \
               -Djava.security.egd=file:/dev/./urandom"

# Run application
ENTRYPOINT ["dumb-init", "--"]
CMD ["sh", "-c", "java $JAVA_OPTS -jar app.jar"]