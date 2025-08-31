package com.company.jenkins

class BuildConfig implements Serializable {
    String buildTool
    String version
    Map<String, String> properties = [:]
    List<String> profiles = []
    boolean skipTests = false
    boolean generateReports = true
    String javaVersion = '11'
    
    BuildConfig(Map config) {
        config.each { key, value ->
            if (this.hasProperty(key)) {
                this."$key" = value
            }
        }
    }
    
    String getBuildCommand() {
        switch(buildTool.toLowerCase()) {
            case 'maven':
                return buildMavenCommand()
            case 'gradle':
                return buildGradleCommand()
            case 'npm':
                return buildNpmCommand()
            default:
                throw new IllegalArgumentException("Unsupported build tool: ${buildTool}")
        }
    }
    
    private String buildMavenCommand() {
        def cmd = ['mvn', 'clean']
        
        if (skipTests) {
            cmd.add('-DskipTests=true')
        }
        
        if (profiles) {
            cmd.add("-P${profiles.join(',')}")
        }
        
        properties.each { key, value ->
            cmd.add("-D${key}=${value}")
        }
        
        cmd.add('package')
        return cmd.join(' ')
    }
    
    private String buildGradleCommand() {
        def cmd = ['./gradlew', 'clean', 'build']
        
        if (skipTests) {
            cmd.add('-x test')
        }
        
        properties.each { key, value ->
            cmd.add("-P${key}=${value}")
        }
        
        return cmd.join(' ')
    }
    
    private String buildNpmCommand() {
        return 'npm ci && npm run build'
    }
    
    Map<String, Object> toMap() {
        return [
            buildTool: buildTool,
            version: version,
            properties: properties,
            profiles: profiles,
            skipTests: skipTests,
            generateReports: generateReports,
            javaVersion: javaVersion
        ]
    }
}