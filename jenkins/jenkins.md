# Jenkins Introduction

- Execute the pipeline within a docker container
```groovy
agent {
    docker {
        image 'maven:3.9.3-eclipse-temurin-17'
        label 'my-defined-label'
        args  '-v /tmp:/tmp'
    }
}
```

- Can use `credentials` inside the environment block.

- `parameters`: block which provides a list of params that the user should provide. Made available to the rest of the pipeline with `params` object. Can be inside the pipeline block.
```groovy
parameters { 
    string(name: 'DEPLOY_ENV', defaultValue: 'staging', description: '')
    choice(name: 'CHOICES', choices: ['one', 'two', 'three'], description: '')
    // first value in a choice is the default
    password(name: 'PASSWORD', defaultValue: 'SECRET', description: 'Enter a password')
}
```

- `when`: conditional directive that must be evaluated to determine whether the stage should be executed.
    - For [Built-In Conditons](https://www.jenkins.io/doc/book/pipeline/syntax/#built-in-conditions)
```groovy
stage('Example Deploy') {
    when {
        branch 'production' // branch condition supports regex with branch pattern
    }
}
```

- `triggers`: directive that defines the automated way the Pipeline should be re-triggered. Accepts `cron`, `pollSCM`, `upstream`.
```groovy
pipeline {
    agent any
    triggers {
        cron('H */4 * * 1-5')
    }
    ...
}
// OR for upstream
triggers {
    upstream(upstreamProjects: 'job1,job2', threshold: hudson.model.Result.SUCCESS)
}
// OR for pollSCM
triggers {
    pollSCM('H */4 * * 1-5')
}
```

- `tools`: manages supported tools: `maven`, `jdk`, or `gradle`. Must be preconfigured in the **Manage Jenkins -> Tools**
```groovy
pipeline {
    agent any
    tools {
        maven 'apache-maven-3.0.1' 
    }
}
```

- `parallel`: contains a list of nested stages to be run in parallel.
```groovy
stage('Parallel In Sequential') {
    ...
    parallel {
        stage('In Parallel 1') {
            steps {
                echo "In Parallel 1"
            }
        }
        stage('In Parallel 2') {
            steps {
                echo "In Parallel 2"
            }
        }
    }
}
```

- `matrix`: defines a matrix of name-value combinations to be run in parallel. Each combination is a 'cell'.
```groovy
matrix {
    axes {
        axis {
            name 'PLATFORM'
            values 'linux', 'mac', 'windows'
        }
        axis {
            name 'BROWSER'
            values 'chrome', 'edge', 'firefox', 'safari'
        }
        axis {
            name 'ARCHITECTURE'
            values '32-bit', '64-bit'
        }
    }
    // ...
}
```


## Pipeline Best Practices

- Use Shell Scripts along with `sh`
- Combine steps wherever possible
- Avoid jsonSlurper or HttpRequest. Instead use sh to jq, or wget/curl respectively

## Groovy Basics

- [Groovy Docs](https://docs.groovy-lang.org/1.8.6/html/groovy-jdk/java/lang/String.html)

- `def`: keyword used to dynamically define a variable or method, without specificying its type explicitly

```groovy
// groovy infers type automagically
def name = "Alice"      // Dynamically assigns a string
def age = 30            // Dynamically assigns an integer
def price = 19.99       // Dynamically assigns a decimal
```

- `new`: Instantiates new objects. Can be used with any class that has a constructor.
```groovy
def date = new Date() // Creates new date object (java.util.Date)
println date

def list = new ArrayList() // Creates empty list (Java ArrayList)
list.add("Groovy")
println list

def hashMap = new HashMap()  // Creates an empty HashMap
hashMap.put("key", "value")
println hashMap
```

- `main()`: The entrypoint of the program, need a main method
```groovy
public static void main(String[] args)
// public - Access specifier, public means globally avail. private is access restricted
// static - keyword, so that JVM can invoke without instantiating class
// void - return type, because main() doesn't return anything, it IS the program
// main - method name, always needing a main()
// args - name of the String array is 'args'
```

- `dir()`: execute a script or commands in another directory
```groovy
steps {
    script {
        dir('some/path/to/dir') {
            ls // executed in the above dir
        }
    }
}
```
- `Path`: java.nio.file, represents a file or directory path in a system-independent way.
```groovy
import groovy.transform.SourceURI
import java.nio.file.Path
import java.nio.file.Paths
import java.net.URI

class ScriptPathHelper {
    @SourceURI // automatically assigns the URI of the script file to static URI variable
    static URI uri  // Injects the script's URI
    // lowercase uri is the variable we defined

    static Path getScriptPath() {
        return Paths.get(uri)  // Convert URI to Path
    }

    static Path getScriptDirectory() {
        return getScriptPath().getParent()  // Get parent directory
    }

    static String getScriptFileName() {
        return getScriptPath().getFileName().toString()  // Get file name
    }

    static File getScriptAsFile() {
        return getScriptPath().toFile()  // Convert Path to File
    }

    static boolean scriptExists() {
        return getScriptAsFile().exists()
    }
}

// Example usage:
println "Script Path: ${ScriptPathHelper.getScriptPath()}"
println "Script Directory: ${ScriptPathHelper.getScriptDirectory()}"
println "Script File Name: ${ScriptPathHelper.getScriptFileName()}"
println "Script Exists? ${ScriptPathHelper.scriptExists()}"
```

- `containsKey`: check if an object contains a specific key. Example:
```groovy
def users = [
    "john_doe" : "john_doe@example.com",
    "jane_smith" : "jane_smith@example.com",
    "alice_wong" : "alice_wong@example.com"
]

// iterate over each key-value pair
users.each { k, v ->
    println "Username: $k, Email: $v"
}
// check if a key exists
def keyToCheck = "alice_wong"

if (users.containsKey(keyToCheck)) {
    println "alice exists"
} else {
    println "who?"
}
```

- `instanceof`: Check if an object is an instance of a specific class or subclass (can be testing if its an instance of "String" of a custom class)
```groovy
def str = "Hello, Groovy!"
println str instanceof String  // true
println str instanceof Integer // false
```

- `mergeConfig(defaultConfig1, overrideUserConfig2)`: merge two maps together. Complex example using `.each`
```groovy
// Method to merge two maps with deep merge support
def mergeConfig(Map defaultConfig, Map userConfig) {
    // Iterate over userConfig and merge with defaultConfig
    userConfig.each { key, value ->
        if (value instanceof Map && defaultConfig[key] instanceof Map) {
            // If both values are maps, merge them recursively
            defaultConfig[key] = mergeConfig(defaultConfig[key], value)
        } else {
            // Otherwise, just overwrite the defaultConfig value with userConfig
            defaultConfig[key] = value
        }
    }
    return defaultConfig
}

// Sample configs
def defaultConfig = [
    timeout  : 30,
    retries  : 3,
    logLevel : "INFO",
    dbConfig : [
        host     : "localhost",
        port     : 5432,
        user     : "admin"
    ]
]

def userConfig = [
    retries  : 5,  // Override default
    logLevel : "DEBUG",  // Override default
    dbConfig : [
        port     : 3306,  // Override port
        password : "secret"  // Add new key
    ],
    apiKey   : "12345XYZ"  // Add new key
]

// Merge configs
def finalConfig = mergeConfig(defaultConfig, userConfig)

// Print final merged config
println "Merged Configuration:"
finalConfig.each { k, v ->
    println "$k: $v"
}
```

### Groovy Classes

- a Groovy class is a collection of data and methods that operate on that data.
```groovy
package com.example // package declaration
// define a class named 'Student'
// contains 2 fields
// contains a 'main' method where an instance of the class is created and assigned
class Student {
    int StudentID; // field which is an instance variable
    String StudentName; // field

    static void main(String[] args) { // Main method which is the entrypoint
        Student st = new Student(); // create an instance of Student
        st.StudentID = 1 // assign value to StudentID
        st.StudentName = "Joe"
    }
}
```
- Then using the class...
```groovy
import com.example.Student
// import the class

class Main {
    // static is a 'modifier', meaning the method belongs to the class itself
    // not an instance of the class
    // We want to call main without creating an object of the class first
    // without static, we would have to create an object of the class
    static void main(String[] args) {
        // Creating a Student object
        Student stduent1 = new Student(1, "Alice")
        student1.displayInfo() // Output: Student ID: 1, Name: Alice

        Student stduent2 = new Student(2, "Bob")
        student1.displayInfo() // Output: Student ID: 2, Name: Bob
    }
}
```
Consuming Classes
| **Method**  | **Usage**    |
|------------|---------------|
| Same File  | Just create and use objects.  |
| Different File (without package)  | Use `load('Student.groovy')` in Groovy scripts. |
| Different File (with package)   | Import using `import com.example.Student`.        |
| Jenkins Shared Library    | Store it in `vars/` and import into a pipeline.   |

### Functions/While loops/Others

- `function`: here is a function
```groovy
def namespaceIsThere(namespace) {
    def getTheNsStatus = script.sh(script: "kubectl get namespace ${namespace} 2>&1 || true", returnStdout: true).trim()
    // 
    script.echo "getTheNsStatus : ${getTheNsStatus}"
    return !getTheNsStatus.contains("Error")
}
```

- `while`: loop example
```groovy
while (condition) {
    println "true"
}
```


- Defining a public Boolean
```groovy
public Boolean isEnabled(String name) {
    config.mods ? config.mods[name] != null : false
}
/** defines a public method named 'isEnabled' that returns a Boolean value
 * method accepts a String param called 'name'
 * standard ternary operator that checks if config.mods exists, and if the name
 * key exists, else return false
 */

 // imagine the below
 def config = [
    mods: [
        "featureA": true,
        "featureB": null
    ]
 ]

 println isEnabled("featureA") // true
```


#### Built-In Classes

- `jsonSlurper`: Class used for parsing JSON text into Groovy objects like maps, lists, primitive types (Integer, Double, Boolean, String)
```groovy
def jsonSlurper = new JsonSlurper()
def object = jsonSlurper.parseText('{ "name": "John Doe" } /* some comment */')

assert object instanceof Map
assert object.name == 'John Doe'
```



## Shared Libraries
A **Shared Library** is defined with a name, a source code retrieval method such as by SCM, and optionally a default version. The name should be a short identifier as it will be used in scripts.

### Directory Structure

```yaml
(root)
+- src                     # Groovy source files
|   +- org
|       +- foo
|           +- Bar.groovy  # for org.foo.Bar class
+- vars
|   +- foo.groovy          # for global 'foo' variable
|   +- foo.txt             # help for 'foo' variable
+- resources               # resource files (external libraries only)
|   +- org
|       +- foo
|           +- bar.json    # static helper data for org.foo.Bar
```
- `src` directory should look like standard Java source dir structure. Added to classpath when executing pipelines
- `vars` directory hosts script files that are exopsed as variables. Name of file == name of variable.
    - So if you had a file called `vars/log.groovy` with a function like `def info(message)…`​ in it, you can access this function like `log.info "hello world"` in the Pipeline.
- `resources` directory allows **libraryResource** step to be used from an external library to load associated non-Groovy files

### Shared Library Reference Example
```groovy
// @Library annotation used on 'somelib' can be git repo or default shared library dir in jenkins
@Library('somelib')
// somelib can contain reusable functions, classes, and global variables to share

//standard groovy import statemnt, imports Helper class which contains 2 methods
import com.mycorp.pipeline.somelib.Helper
// com/mycorp/pipeline/somelib/Helper.groovy is the path to the method Helper

// method definition in Groovy
// method named 'useSomeLib' and accepts 1 arg 'helper'
// 'helper' is expected to be an instance of the 'Helper' class defined in the lib
// 'int' indicates that the method should return an integer type value
int useSomeLib(Helper helper) {
    helper.prepare()
    return helper.count()
}

echo useSomeLib(new Helper('some text'))
```


## Variable Reference

### Global Variables

- Only contains documentation for variables provided by Pipeline or plugins, which are available for Pipelines.

- Default variables provided in Pipeline:
    - `env`: exposes environment variables. Example: `env.PATH` or `env.BUILD_ID`
    - `params`: exposes all parameters defined for the Pipeline as a read-only Map. `params.MY_PARAM`
    - `currentBuild`: used to discover info about the currently executing Pipeline. Properties include: `currentBuild.result`, `currentBuild.displayName`

### All Environment Variables

- `BUILD_ID` - identical to build number
- `BUILD_NUMBER` - i.e "144"
- `BUILD_TAG` - String of `jenkins-${JOB_NAME}-${BUILD_NUMBER}`.
- `BUILD_URL` - example: http://buildserver/jenkins/job/myjob/144
- `EXECUTOR_NUMBER` - The number you see in "build executor status"
- `JAVA_HOME` - configured to use specific JDK, when set, PATH is also updated to include bin of JAVA_HOME
- `JENKINS_URL` - https://example.com:port/jenkins/
- `JOB_NAME`
- `NODE_NAME` - name of the node current build is running on. Set to 'master' for Jenkins controller
- `WORKSPACE` - absolute path of the workspace

### Using Environment Variables

```groovy
pipeline {
    agent any
    environment {
        CC = 'clang'
    }
    stages {
        stage('Example') {
            environment { // only available within this stage's steps
                DEBUG_FLAGS = '-g'
            }
            steps {
                sh 'printenv'
            }
        }
    }
}
```

## Credentials Handling

- declarative pipelines have the `credentials()` helper method, which supports secret text, usernames, passwords, and secret files.
- First configure the credentials directly within jenkins `jenkins-azure-client-id`
- Next, reference within environment block in like `credentials('jenkins-azure-client-id')`

```groovy
pipeline {
    agent {
        // Define agent details here
    }
    environment {
        AWS_ACCESS_KEY_ID     = credentials('jenkins-aws-secret-key-id')
        AWS_SECRET_ACCESS_KEY = credentials('jenkins-aws-secret-access-key')
    }
    stages {
        stage('Example stage 1') {
            steps {
                //
            }
        }
        stage('Example stage 2') {
            steps {
                //
            }
        }
    }
}
```
- Credentials can be combined like BITBUCKET_CREDS = `username:password`
- Secret Files are uploaded directly to jenkins, like a kubeconfig

## More Pipeline Syntax

- `options`: options block inside 'pipeline' block with several options: `timeout`, `buildDiscarder`, `disableConcurrentBuilds` for example
```groovy
pipeline {
    agent any
    options {
        timeout(time: 1, unit: 'HOURS')
        buildDiscarder(logRotator(
            daysToKeepStr: '30'
            numToKeepStr: '10' //
        ))
    }
}
```

- `withCredentials`
```groovy
withCredentials([[$class: 'UsernamePasswordMultiBinding', credentialsId: 'credentialsId', usernameVariable: 'USER', passwordVariable: 'PASS']]) {
    // Actions where the credentials are available
}
```

- `catchError`: throw an exception and mark build as failure, but continue the pipeline
```groovy
catchError {
        sh 'might fail'
    }
```
- `try`, `catch`, `finally`: blocks can be used
```groovy
try {
        sh 'might fail'
        echo 'Succeeded!'
    } catch (err) {
        echo "Failed: ${err}"
    } finally {
        sh './tear-down.sh'
    }
```
- `deleteDir`: Rercursively delete the current dir from the workspace.
- `fileExists`: checks if given file exists on current node, returns `true | false`. Needs to be wrapped in `script {}` block.
```groovy
script {
    if (fileExists('src/path/to/file.txt')) {
        echo "File exists"
    }
}
```
- `mail`: simple step for sending email
```groovy
script {
    mail to: 'team@example.com',
         subject: "Build Status: ${currentBuild.currentResult}",
         body: "The build has finished with result: ${currentBuild.currentResult}.",
         mimeType: 'text/html'
}
```
- `sh`: execute a shell command or script.
- `withEnv`: Sets environment variables within a block.
```groovy
script {
  withEnv(['MYTOOL_HOME=/usr/local/mytool']) {
    sh '$MYTOOL_HOME/bin/start'
  }
}
```
- `archiveArtifacts`: archives build output artifacts for later use
- `getContext`: Get contextual object from internal APIs. For use from code that can manipulate internal Jenkins APIs.

## Troubleshooting

-