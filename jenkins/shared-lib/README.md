# Jenkins MPL?

The **Jenkins MPL** (multi-branch pipeline library) is a collection of reusable Groovy scripts that are versioned and stored in a source control repository. These libraries are designed to be imported and called from a **Jenkinsfile** using the `@Library` annotation. Instead of writing the same build steps in every Jenkinsfile, you can define them once in the MPL and reference them from any pipeline. This approach promotes the DRY (Don't Repeat Yourself) principle and streamlines the maintenance of your CI/CD processes.

```txt
shared-library/
├── vars/                    # Global variables (pipeline steps)
│   ├── buildApplication.groovy
│   ├── deployToEnvironment.groovy
│   ├── notifySlack.groovy
│   └── runTests.groovy
├── src/                     # Object-oriented Groovy classes
│   └── com/
│       └── company/
│           └── jenkins/
│               ├── BuildConfig.groovy
│               ├── DeploymentManager.groovy
│               └── NotificationService.groovy
├── resources/               # Static resources
│   ├── scripts/
│   │   ├── docker-build.sh
│   │   └── k8s-deploy.yaml
│   ├── templates/
│   │   └── sonarqube.properties
│   └── configs/
│       └── quality-gates.json
└── test/                    # Unit tests (optional)
    └── groovy/
        └── vars/
            └── BuildApplicationTest.groovy
```

## Key Components

`vars/`: This is the core of the MPL. It contains global variables written in Groovy. Each file in this directory represents a shared function that can be called directly from a pipeline. For example, a file named `slackNotifier.groovy` could contain a function for sending notifications to Slack.

`src/`: This directory holds more complex, object-oriented Groovy code. It's for creating **classes** and **helper methods** that can be imported and used within your pipeline scripts.

`resources/`: This directory is for non-Groovy files, like shell scripts, configuration templates, or YAML files, that your library functions might need to access.

How it works

When a pipeline with the `@Library` annotation is triggered, Jenkins fetches the specified library from its source control repository. The scripts in the library are then available to be called from the **Jenkinsfile**, just as if they were part of the script itself. This dynamic loading and execution of code is a powerful feature that makes pipelines more modular and scalable.

## How to use it

1. Global Tool Config

```groovy
Name: shared-lib
Default version: master
Retrieval method: Modern SCM
  Source Code Management: Git
  Repository URL: https://github.com/company/jenkins-shared-library.git
  Credentials: jenkins-git-credentials
  Behaviors: Discover branches, Discover tags
```

2. Library Loading Options

To use this library in your `Jenkinsfile`, add the following line at the top:

```groovy
// Load specific version
@Library('shared-lib@v1.2.3') _
// Load from branch
@Library('shared-lib@develop') _
// Load default version (configured in Jenkins)
@Library('shared-lib') _
// Load without implicit import
@Library('shared-lib@master') import com.company.jenkins.*
// Load multiple libraries
@Library(['shared-lib@master', 'utils-lib@v2.0.0']) _
// Dynamic loading (not recommended for production)
library('shared-lib@master')
// shared-lib is the libary name configured in Manage Jenkins
// @master is the optional branch name, defaults to libs configured version
// _ means load the library without assigning to a variable
```



Once loaded, any vars/*.groovy file is exposed as a global step. This helps keep Jenkinsfiles minimal, only passing configuration and keeping the logic elsewhere.

Use versioned references in production.