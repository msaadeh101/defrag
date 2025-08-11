# Maven

## Overview

- **Apache Maven** is a build automation and project management tool primarily for Java projects. It uses a **Project Object Model (POM)** and set of plugins to build, manage dependencies, and automate various project lifecycle tasks. Particularly useful for its seamless integration with CI/CD pipelines.

## Key Features

- **Dependency Management**: 
  - Automatically resolves and downloads dependencies recursively.
  - Handles version conflicts using nearest-wins strategy.
  - Supports local, central, and remote repos.
  - Supports different scopes: compile, test, runtime, etc
- **Build Lifecycle Management**:
  - Predefined lifecycles like default, clean, and site with predefined phases.
  - Plugin architecture and supports project structures with parent-child relationships.
  - Profiles: Envrionment-specific configurations.
- **Project Structure Standardization**:
  - Naming conventions for naming/versioning.
  - Built-in report capabilities.
- **Repository System**:
  - `Local Repo`: Cached dependencies on dev machines.
  - `Central Repo`: Default public repo with 1,000s of artifacts.
  - `Private Repo`: Support for corporate artifact repositories like Nexus or Artifactory.
  - `Snapshot vs Release`: Distinguish between development and stable versions.

## CLI

- Basic Commands:

```bash
# Create a new project from archetype
mvn archetype:generate \
  -DgroupId=com.company.app -DartifactId=my-app \ -DarchetypeArtifactId=maven-archetype-quickstart
# Clean previous builds
mvn clean
# Compile source code
mvn compile
# Run tests
mvn test
# Package the project (creates JAR/WAR)
mvn package
# Install artifact to local repository
mvn install
# Deploy artifact to remote repository
mvn deploy
# Combined lifecycle phases
mvn clean install
mvn clean package
mvn clean compile test
```

- Advanced Commands:

```bash
# Skip tests during build
mvn clean install -DskipTests
mvn clean install -Dmaven.test.skip=true
# Run with specific profile
mvn clean install -Pproduction
# Run in offline mode
mvn clean install -o
# Enable debug output
mvn clean install -X
# Show dependency tree
mvn dependency:tree
# Analyze dependency conflicts
mvn dependency:analyze
# Update snapshots
mvn clean install -U
# Generate project site documentation
mvn site
# Run specific plugin goals
mvn compiler:compile
mvn surefire:test
mvn jacoco:report
```

## Installation

- **Prerequisites**: JDK 8 +, `JAVA_HOME` set.

- **Download and Install**:

```bash
# Download Maven from https://maven.apache.org/download.cgi
wget https://dlcdn.apache.org/maven/maven-3/3.9.6/binaries/apache-maven-3.9.6-bin.tar.gz
# Extract
tar -xzf apache-maven-3.9.6-bin.tar.gz
sudo mv apache-maven-3.9.6 /opt/maven
# Set environment variables
export MAVEN_HOME=/opt/maven
export PATH=$PATH:$MAVEN_HOME/bin
# Verify installation
mvn --version
```

- **Package Manager**:

```bash
sudo apt update && sudo apt install maven
```

## Configuration

- Settings.xml Location:
  - Global: `$MAVEN_HOME/conf/settings.xml`
  - User: `~/.m2/settings.xml`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<settings xmlns="http://maven.apache.org/SETTINGS/1.0.0">
  
  <!-- Local repository location -->
  <localRepository>~/.m2/repository</localRepository>
  
  <!-- Server credentials for deployment -->
  <servers>
    <server>
      <id>nexus-releases</id>
      <username>deployment-user</username>
      <password>deployment-password</password>
    </server>
  </servers>
  
  <!-- Mirror configuration -->
  <mirrors>
    <mirror>
      <id>nexus</id>
      <mirrorOf>central</mirrorOf>
      <name>Corporate Nexus</name>
      <url>http://nexus.company.com/repository/maven-public/</url>
    </mirror>
  </mirrors>
  
  <!-- Profiles -->
  <profiles>
    <profile>
      <id>development</id>
      <properties>
        <environment>dev</environment>
      </properties>
    </profile>
  </profiles>
  
  <!-- Active profiles -->
  <activeProfiles>
    <activeProfile>development</activeProfile>
  </activeProfiles>
</settings>
```

- **Environment Variables**:

```bash
# Essential environment variables
export JAVA_HOME=/path/to/java
export MAVEN_HOME=/path/to/maven
export M2_HOME=$MAVEN_HOME  # Legacy, but some tools still use it
export PATH=$PATH:$MAVEN_HOME/bin

# Maven-specific options
export MAVEN_OPTS="-Xmx2048m -XX:MaxPermSize=256m"
export MAVEN_SKIP_RC=true  # Skip loading of mavenrc files
```

## Project Structure and POM

```text
my-project/
├── pom.xml
├── src/
│   ├── main/
│   │   ├── java/          # Java source code
│   │   ├── resources/     # Resources (properties, XML, etc.)
│   │   └── webapp/        # Web application files (for WAR projects)
│   └── test/
│       ├── java/          # Test source code
│       └── resources/     # Test resources
├── target/                # Build output (generated)
└── README.md
```

- POM.xml

```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0">
    <modelVersion>4.0.0</modelVersion>
    
    <!-- Project coordinates -->
    <groupId>com.company.myapp</groupId>
    <artifactId>my-application</artifactId>
    <version>1.0.0-SNAPSHOT</version>
    <packaging>jar</packaging>
    
    <!-- Project information -->
    <name>My Application</name>
    <description>Sample application for DevOps</description>
    
    <!-- Properties -->
    <properties>
        <maven.compiler.source>11</maven.compiler.source>
        <maven.compiler.target>11</maven.compiler.target>
        <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
        <junit.version>5.8.2</junit.version>
    </properties>
    
    <!-- Dependencies -->
    <dependencies>
        <dependency>
            <groupId>org.junit.jupiter</groupId>
            <artifactId>junit-jupiter</artifactId>
            <version>${junit.version}</version>
            <scope>test</scope>
        </dependency>
    </dependencies>
    
    <!-- Build configuration -->
    <build>
        <plugins>
            <plugin>
                <groupId>org.apache.maven.plugins</groupId>
                <artifactId>maven-compiler-plugin</artifactId>
                <version>3.10.1</version>
            </plugin>
            <plugin>
                <groupId>org.apache.maven.plugins</groupId>
                <artifactId>maven-surefire-plugin</artifactId>
                <version>3.0.0-M7</version>
            </plugin>
        </plugins>
    </build>
</project>
```

## Build Lifecycle

- **Default Lifecycle**: Handles main build process from validating the project through compiling, testing, packaging, deployment.
1. validate:
1. compile:
1. test:
1. package:
1. verify:
1. install:
1. deploy:

- **Clean Lifecycle**: Responsible for cleaning up build artifacts and temp files created during build, ensuring a fresh start.
1. pre-clean:
1. clean:
1. post-clean:

- **Site Lifecycle**: Generates project documentation, reports, and a website containing the information.
1. pre-site:
1. site:
1. post-site:
1. site-deploy:

## Integrations and Troubleshooting

- **Docker**:

```dockerfile
# Multi-stage build
FROM maven:3.9.6-openjdk-11 AS build
WORKDIR /app
COPY pom.xml .
RUN mvn dependency:go-offline -B
COPY src ./src
RUN mvn clean package -DskipTests

FROM openjdk:11-jre-slim
WORKDIR /app
COPY --from=build /app/target/*.jar app.jar
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
```

- Troubleshoot Dependency Resolution issues:

```bash
# check local repo cache before deleting
ls ~/.m2/repository
# Force update snapshots
mvn clean install -U
# Analyze dependency tree
mvn dependency:tree -Dverbose
```
- Troubleshoot Memory Issues:

```bash
# Increase memory allocation For Java 8+
export MAVEN_OPTS="-Xmx4g -XX:MetaspaceSize=512m"
```

- **Debug commands**:

```bash
# Enable debug logging
mvn clean install -X
# Show effective POM
mvn help:effective-pom
# Show effective settings
mvn help:effective-settings
# Analyze project
mvn help:describe -Dcmd=compile
mvn dependency:analyze-only
mvn versions:display-dependency-updates
```

- **Note**: Build Optimization: enable parallel builds with `-T`