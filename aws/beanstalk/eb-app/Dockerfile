# ---- Build stage ----
# Pinned Maven+JDK version for reproducibility
FROM maven:3.9.6-eclipse-temurin-17 as build
WORKDIR /app

# Copy pom.xml first to leverage dependency caching
COPY pom.xml .
RUN mvn dependency:go-offline

# Copy the remaining source files
COPY . .

# Build package without running tests (tests should run in CI/CD, not here)
RUN mvn clean package -DskipTests

# ---- Runtime stage ----
# Use a slim, stable JRE base image
FROM eclipse-temurin:17-jre-jammy
WORKDIR /app

# Copy only the jar artifact from the build stage
COPY --from=build /app/target/*.jar app.jar

# Create an unprivileged user to run the application
RUN useradd --system --uid 1001 --no-create-home spring
RUN chown -R spring:spring /app
USER spring

# JVM options: container aware memory limits, efficient GC, string deduplication, disable JMX
ENV JAVA_OPTS="-XX:MaxRAMPercentage=75.0 \
  -XX:+UseG1GC \
  -XX:G1HeapRegionSize=16m \
  -XX:+UseStringDeduplication \
  -Dspring.jmx.enabled=false"

# Document the application port (not required at runtime)
EXPOSE 8080

# Use exec form for proper signal handling in containerized environments
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
