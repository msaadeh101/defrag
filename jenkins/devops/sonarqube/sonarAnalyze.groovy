package com.company.devops.pipeline.Sonar // places the class inside 'com.company.devops.pipeline.Sonar'

class sonarAnalyze implements Serializable {
    // serializable means the class instances can be reused across pipeline stages. 

    protected script // reference to the Jenkins pipeline script
    protected credentialsId // used to access sonarqube credentials
    protected sonarServerID // The SonarQube server configured in Jenkins.
    protected sonarScanner // holds the executable or path for the scanner cmd line tool
    protected sonarProjectName
    protected sonarURL
    protected javaHome // path of Java home dir, needed for Java-based projects
    protected coverageExclusions

    /**
     *
     * @param script
     * @param credentialsId
     * @param sonarServerID
     * @param sonarScanner
     * @param sonarProjectName
     * @param sonarURL
     */
    sonarAnalyze(script, credentialsId, sonarServerID, sonarScanner, sonarProjectName, sonarURL, javaHome, coverageExclusions) {
    // this is the constructor, it initializes the class with user-defined parameters
    // these values will be passed when instantiating the class inside a Jenkins pipeline

        this.script = script
        this.credentialsId = credentialsId
        this.sonarServerID = sonarServerID
        this.sonarScanner = sonarScanner
        this.sonarProjectName = sonarProjectName
        this.sonarURL = sonarURL
        this.javaHome = javaHome
        this.coverageExclusions = coverageExclusions

    }

    /**
     *
     * @return
     */
     def sonarScan() {
        // sonarScan is a method, it performs the actual sonarqube scan by running the sonar-scanner command

        // below configures the java environment.
         script.withEnv(["JAVA_HOME=${javaHome}", "PATH=${script.env.PATH}:${script.env.JAVA_HOME}/bin"]) {
             // below line sets up sonarqube environment
             // loads the sonarqube environment in Jenkins using sonarServerID
             // allows sonar scanner to use Jenkins configured creds without exposing them
             // script.with* constructs are used to temp modify env, or execute within a given context.
             script.withSonarQubeEnv(sonarServerID) {
                 script.sh """ 
                          echo ${script.env.JAVA_HOME}
                          $sonarScanner \
                         -Dsonar.projectName=$sonarProjectName \
                         -Dsonar.projectKey=$sonarProjectName \
                         -Dsonar.coverage.exclusions=$coverageExclusions \
                         -Dsonar.analysis.mode= \
                         -Dsonar.host.url=$sonarURL \
                         -Dsonar.password= \
                         -Dsonar.web.javaAdditionalOpts="-Dsonar.web.maxPostSize=504857600" \

                        """
             }
         }
    }

}