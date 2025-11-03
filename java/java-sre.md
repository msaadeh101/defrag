# Java SRE

## Core Java Deep Dive

- Understand how code executes at runtime - resource management, shared state, application flow.
- Focus on Exception handling, JVM and perf tuning, remote debugging and logging frameworks.

### Concurrency and MultiThreading

- The majority of complex, intermittent production issues (high latency, request drops, server hangs) stem from concurrency problems.

- **Java Memory Model (JMM)**:
    - Understand the difference between the **main memory** and **thread working memory**. The JMM governs when a thread's changes are visible to other threads.
    - `volatile`: ensures reads/writes of a variable go straight to main memory, ensuring **visibility** across threads, but *NOT* atomicity. Use if for status flags or counters that don't depend on their current value.
    - `synchronized`: provides both **mutual exclusion** (only one thread can execute a block) and **memory visibility**. It's heavy and can cause lock contention.
    - **Immutability**: A key pattern for reliability, making objects immutable (using final and no setter methods) guarantees thread-safety and reduces concurrency bugs.

- **`java.util.concurrent` Package**: Avoid implementing your own locking mechanisms, use the tools in the java util package concurrent.
    - Executors and ThreadPools: Understand `FixedThreadPool`, `CachedThreadPool`, `ScheduledThreadPool`.
    - Understand how to prevent thread starvation (threads busy with long tasks) or excessive resource consumption.
    - **Thread Synchronization Tools**: `ReentrantLock` (more flexible than synchronized), `Semaphore` (to limit concurrent access to a resource), and `CountDownLatch` (to make one thread wait for others.)

- **Diagnosing Issues**: The first step is taking a **thread dump** using `jstack`. You must read the thread dump and identify:
    - Threads in `BLOCKED` state due to lock contention.
    - **Deadlocks** (two or more threads permanently waiting for each other).
    - Threads in `WAITING` or `TIMED_WAITING` states.

#### Sizing Thread Pools

- Correctly sizing a thread pool is the first step in avoiding thread starvation (too small) and resource exhaustion (too large). Optimal size depends on the task type.


|Task Type| Goal| Optimal Pool Size Formula| Example|
|-----|-----|------| ------|
|CPU-Bound | Maximize CPU utilization, minimize context switching overhead.| `Nthreads​=Ncores​+1` | Service doing heavy calculations, compressions, ML. 8 cores -> 9 threads|
| I/O-Bound | Keep cores busy while threads are blocking (waiting for Input/Output). | `Nthreads​=Ncores​×(1+W/C)` | Microservice calling many others, or a database. 8 cores, W=1s, C=100ms = 8 * (1+10) -> 88 threads|

- **Ncores** is the number of available CPU cores (`Runtime.getRuntime().availableProcessors()`).
- **W (Wait Time)** is the time spent waiting for external resources (DB, network, disk Input/Output).
- **C (Compute Time)** is the time spent performing the CPU-intensive workloads.
- Prefer custom `TheadPoolExecutor` with a bounded queue to control load, and a `RejectedExecutionHandler` to handle overflow situations gracefully.

#### Reading a Thead Dump for RCA

- A **thread dump** is a snapshot of all threads and their stack traces, current states, held locks, and waiting dependencies, which is the primary tool for diagnosing production hangs or high-CPU incidents.

|State |Meaning |How to Spot in Stack Trace | Common RCA Insights |
|------|-----------|-----------------------| ----------|
| `RUNNABLE` | The thread is **actively executing**, or is **ready to execute** (waiting for CPU time).| If a thread is stuck in `RUNNABLE` across multiple dumps (10 seconds apart), indicates an expensive computation (**CPU bottleneck**) or an **infinite loop**. Often shows active method frames `compute`, `parse`, `hash`, `sort`.| If same threads remain `RUNNABLE` across multiple dumps, they could cause CPU saturation or infinite loops. Use `top -H` to match thread IDs (`nid`) with CPU usage.| 
| `BLOCKED`| The thread is waiting to acquire a monitor lock (due to a `synchronized` block/method) that is currently held by another thread.| The stack trace will show `waiting to lock <0x...>` and `locked <0x...>` in other threads. A large number of blocked threads pointing to the same lock is **lock contention**.|  A large group blocked on same lock suggests **lock contention** or a **deadlock**. Investigate owner's state and stack trace.|
| `WAITING` | The thread is **waiting indefinitely** for another thread to perform a particular action (e.g., `Object.wait()`, `Thread.join()`, or an **unbounded** `LockSupport.park()`). | Look for internal framework methods like `park()`, `await()`, or a `join()` call. If it's a worker thread, it's likely just waiting for new work (normal).| For worker threads (executors) this is normal when idle. For critical threads, persistent `WAITING` could mean **dependency stalling** or **downstream backpressure**.|
| `TIMED_WAITING` | The thread is waiting for a **specified maximum time** (e.g., `Thread.sleep(100)`, `LockSupport.parkNanos()`).|  Normal for most thread pool executors, which use this state to wait for new tasks before timing out.| Normal in schedulers or pool executors. Prolonged or uneven distribution among worker threads could be **queue starvation** or **task submission imbalance** |

**Common RCA Workflows**
1. **CPU Hangs or 100% Utilization**
- Collect 3 thread dumps 10 seconds apart.
- Identify threads repeatedly in RUNNABLE.
- Match top CPU-consuming threads using `jstack` + `top -H` for `nid` -> OS TID mapping.
- Examine method at top of each stack (e.g. regex parsing, JSON serialization loops).
2. **Application Freeze or No Response**
- Look for threads stuck in `BLOCKED` on same lock.
- Identify owner (thread holding the locked `<0x...>` reference).
- Trace lock chains if multiple locks are involved (deadlock pattern).
3. **Thread Pool Exhaustion**
- Check `WAITING` or `TIMED_WAITING` worker threads with framework executor names (e.g. `http-nio`, `ForkJoinPool`, `OkHttp`, `DefaultDispatcher`).
- All workers idle + pending requests in metrics/logs -> **task submission stall**.
- All workers in RUNNABLE -> **slow tasks or blocking I/O**.
4. **Sutck I/O or External Dependency**
- Look for socket or file operations (`SocketInputStream.socketRead0`, `sun.nio.ch.SocketChannelImpl.read`).
- WAITING on external I/O can point to **database, HTTP or cache dependency slowness**.

### Collections Framework Internals

- **`HashMap` vs. `ConcurrentHashMap`**:
    - `HashMap` is **not thread-safe** - using it in a multithreaded application can lead to data loss or infinite loops.
    - `ConcurrentHashMap` is the standard thread-safe alternative, offering much better performance than a synchronized Map by **dividing the data structure into segments**.

|Aspect	| HashMap	| ConcurrentHashMap |
|-----|------------|--------------------|
| **Thread Safety**	| Not thread-safe; concurrent access can corrupt internal buckets, leading to lost entries or infinite loops during rehash.	| Thread-safe under concurrent access. Designed for high scalability under read-mostly workloads.| 
| **Internal Structure**| 	Array of Nodes (buckets), each a linked list or tree for hash collision buckets.| 	Also uses buckets but employs fine-grained locking or lock striping. Per-bucket synchronized updates with atomic CAS operations.| 
| **Concurrency Control**| 	No synchronization. Requires external synchronization if shared. | Uses segment-level or bin-level locks, reducing contention drastically compared to a synchronized map.| 
| **Scalability**| 	Collapses under concurrent writes. Multiple threads can cause infinite loops during resize.| 	Scales linearly for concurrent reads and well for concurrent writes due to **lock contention minimization**.| 
| **Performance Pattern**	| Fastest single-thread map.| 	Small CPU overhead per update, optimized for concurrent throughput.| 

- **`ArrayList` vs. `LinkedList`**:
    - `ArrayList` is backed by an array; insertion/deletion in th emiddle is slow `(O(N))`, but random access is fast `(O(1))`.
    - `LinkedList`: uses a double-linked list - insertion/deletion is fast `(O(1))`, but random access is slow `(O(N))`.
    - Using the wrong list in a high-volume process can turn a linear-time operation into a quadratic one, causing huge performance degradation.

| Aspect| 	ArrayList| LinkedList| 
|------|------------|------------|
| **Internal Structure**| Resizable array. Elements stored contiguously in memory.	| Doubly linked list nodes containing **prev and next pointers**.| 
| **Element Access**| 	Direct access by index (O(1)) is constant time complexity.	| Sequential traversal (O(N)) is linear time complexity.| 
| **Insert/Delete**	| Expensive in the middle (array copy).	| Constant time insert/delete once position is reached.| 
| **Memory Overhead**| 	Compact, predictable memory footprint.	| **Higher overhead**: two extra object references per element (pointers).| 
| **Cache Locality**| 	Excellent (array-based). | Poor; scattered objects produce cache misses.| 
| **Iterator Characteristics**	| Fast iteration using index-based traversal.	| Iterator walks node references; more GC churn.| 

- Using `LinkedList` in a high-frequency random API (request batching) it can introduce severe latency due to O(N) lookup cost.
- Using an `ArrayList` in workloads with frequent mid-list insertions, can spike CPU due to internal copy operations.
- Use Async-stack traces or allocation profiling to diagnose these list type misuses.

- **Iterators and Fail-Fast Behavior**: Understand the *fail-fast* nature of most collection iterators. They monitor a modification count (`modCount`) for structural changes.
    - If a collection is structurally modified **while being iterated over** (e.g. adding an element), the iterator throws a `ConcurrentModificationException`. 
    - This indicates a shared collection use across multiple threads without appropriate synchronization.


### Exception Handling and Recovery

#### Exception Hierarchy

- **Checked Exceptions**: You are forced to handle them, compelled to recover from exceptions. They indicate anticipated external problems.
    - `IOException` for file or network issues.
    - `SQLException` for database errors.
    - Because they extend from `Exception` class, the compiler enforces `try-catch` handling or declaration in the method signature with `throws`.

- **Unchecked Exceptions (`RuntimeException`)**: Indicate programming errors, which are **bugs** that need to be fixed.
    - `NullPointerException`
    - `IndexOutOfBoundsException`
    - `ConcurrentModificationException`
    - Because they stem from `RuntimeException` class, the compiler does not require explicit handling. Developer should find the root cause elsewhere, rather than wrapping it in try-catch blocks.

- **Errors (`Error`)**: Indicate serious problems that are usually unrecoverable - the JVM is in a compromised state. You cannot handle these directly.
    - `OutOfMemoryError`
    - `StackOverflowError` 
    - `InternalError` 
    - Do not handle directly since recovery is often not possible. Instead: log, alert, and clean shutdown/restart should be the response (Kubernetes should do this).

#### Finally and Try-With-Resources

- **`finally` block**: The finally block **always executes**, even if an exception is thrown or a return is encountered, making it essential for resource cleanup.

```java
FileInputStream in = null;
try {
    in = new FileInputStream("config.properties");
    // perform some file operations
} catch (IOException e) {
    log.error("Error reading configuration", e);
} finally {
    if (in != null) {
        try {
            in.close();
        } catch (IOException e) {
            log.warn("Resource failed to close", e);
        }
    }
}
```

- `try-with-resources`: Imrpoves reliability and Reduces boilerplate over finally block. It ensures that resources that implement `AutoClosable` or `Closeable` (like db connections, file streams, sockets) are closed reliably, **preventing resource leaks** better than finally cleanup.
    - Any object declared inside `try(...)` must implement `AutoCloseable`/`Closeable` - it will automatically close when try block is finished. No need for a finally block.

```java
try (BufferedReader reader = new BufferedReader(new FileReader("data.txt"))) {
    return reader.readLine();
} catch (IOException e) {
    log.error("Failed to read line", e);
}
```

## JVM and Performance Tuning

- The **Java Virtual Machine** serves as both an execution platform and runtime optimizer. Performance involves tuning the JVM's configurable parameters, memory management policies, and runtime diagnostics to achieve desired throughput + latency.

### Gargage Collection

- **Garbage Collection (GC)** automates memory management by reclaiming heap objects that are no longer referenced. The JVM divides the heap into multiple generations.
    - **Young Generation**: Newly allocated objects reside here. 
        - Further divided into **Eden** (first created) and then two **Survivor** spaces (for short-lived object promotion). 
        - A **minor GC** cleans these regions frequently, with minimal pause times.
    - **Old (Tenured Generation)**: Objects that survive multiple minor collections move to the old generation.
        - A **major (full) GC** reclaims this region but can cause application pauses if not tuned properly.

#### Gargage Collection Algorithms

- **Serial GC (`-XX:+UseSerialGC`)**: Simple, single-threaded collector suited for small heaps or single-threaded apps.
- **Parallel GC (`-XX:+UseParallelGC`)**: Uses multiple threads for young and old generation collections. Optimized for througput in large, multi-core systems.
- **G1 GC (`-XX:+UseG1GC`)**: Default for most modern JDKs. Balances low latency and high throughput by dividing the heap into regions and performing **concurrent compaction** to reduce pause times.
- **ZGC (`-XX:+UseZGC`) and Shanendoah GC (`-XX:+UseShanendoahGC`)**: Advanced collectors designed for ultra-low pause times (ms) with **concurrent heap management**.

#### Tuning Strategies

- Align heap size with typical live data size plus 20-30% buffer (`-Xms`, `-Xmx`).
- Use GC Logs (`-Xlog:gc*`) to monitor pause times and collection frequency.
- Avoid frequent full GCs by adjusting survivor ratios (`-XX:SurvivorRatio`), threshld, promotions, and allocation rates.
- For **ultra low latency** (trading engines or API gateways), favor `G1GC` or `ZGC` for predictability.

#### GC Metrics

Monitoring the following metrics helps identify memory leaks, object churn, or insufficient heap sizing:
- GC pause duration.
- Allocation rate (bytes/sec).
- Promotion rate (objects moving from young to old).
- Heap occupancy percentage after GC.

### JVM Monitoring and Profiling Tools

#### Built-In Tools

- `jstat`: Report GC statistics, memory pool usage, and class loading counts in real time.

```bash
# Find the Process ID of Java app (MyApp), run jstat
PID=$(pgrep -f "java.*MyApp")
# -gcutil displays summary of GC stats
# % memory for (S0, S1, E, Old, M, CCS) and counts GC events (YoungGC, FullGC)
jstat -gcutil $PID$ 2000 # 2000 is the sampling interval in ms
# Output:
# S0     S1     E      O      M     CCS    YGC     YGCT    FGC    FGCT     GCT
# 0.00   0.00  34.56  45.12  98.76  95.43   125    1.500     2     0.250    1.750
```

- `jmap`: Generates heap dumps and provides summary of memory regions. **This can cause a brief service interruption as it pauses the JVM**.

```bash
# -dump generates heap dump, format=b is binary
# live dumps only objects reachable/live from GC roots
jmap -dump:live,format=b,file=/tmp/heapdump_$(date +%F_%H-%M-%S).hprof <pid>
```

- `jstack`: Captures thread dumps snapshot for diagnosing deadlocks, blocked threads, or high CPU usage. Capture 3-5 dumps thread dumps (5-10s apart) when diagnosing high CPU issues.
    - Map the high-CPU native thread (from `top -H -p <pid>`) to the thread dump's NID (Native ID) to pinpoint exact code location that is showing up in the stack trace.

```bash
PID=$(pgrep -f "java.*MyApp")
# Capture a thread dump and save it to a file
jstack -l $PID > /tmp/thread_dump_$(date +%F_%H-%M-%S).txt
```

- `jcmd`: A modern unified command interface combining jmap, jstat, and jstack functionalities.

```bash
PID=$(pgrep -f "java.*MyApp")
# jstack equivalent thread dump
jcmd $PID Thread.print
# jmap equivalent heap dump
jcmd $PID GC.heap.dump /tmp/jcmd_heapdump.hprof
```

- `jconsole` and `VisualVM`: GUI-based tools for real-time monitoring of heap, threads, and classes through **JMX (Java Management Extensions)**

```bash
# Run the command to launch GUI
jconsole
# Select the local or remote java process to connect to
# Use tabs (Memory, Threads, Classes, MBeans) to monitor and diagnose issues
```


#### Advanced Profiling Tools

- **Java Flight Recorder (JFR)**: Low-overhead event recorder built into the JVM that captures GC, thread, I/O events with minimal runtime impact. Use JDK Mission Control (JMC) to visualize the memory trends, thread analysis, and GC summaries from the `.jfr` file.

```bash
PID=$(pgrep -f "java.*MyApp")
# Start recording named MyRecording for 60s
jcmd $PID JFR.start duration=60s name=MyRecording filename=/tmp/my_flight_recording.jfr
# If you don't use duration, must stop explicitly with:
jcmd $PID JFR.stop name=MyRecording
# Analyze the .jfr using JDK Mission Control JMC
```

- **Async Profiler**: Lightweight sampling profiler that visualizes CPU usage (wall clock time) and allocation hotspots using **flame graphs**. The flame graph is generated as a .svg you can open in the browser.

```bash
# Profile for 30s and generate interactive svg flame graph
./profiler.sh start $PID -d 30 -f /tmp/cpu_flame_graph.svg
# Open the generated svg in a browser
```

- **YourKit**/**JProfiler**: Commercial profilers with advanced visualization for object allocation, tracking, SQL call profiling, and thread contention graphs.

#### Runtime Observability Hooks

- **Micrometer + Prometheus** / **OpenTelemetry** integration for GC, memory and thread metrics.
    - Micrometer: acts as the metrics facade. It allows devs to instrument their code once.
    - Prometheus: time-series database and alerting system. `/actuator/metrics` (Spring Boot apps).
    - Otel: vendor-neutral observability framework to unify metrics/traces/logs.

```xml
<dependencies>
    <dependency>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-actuator</artifactId>
    </dependency>
    <dependency>
        <groupId>io.micrometer</groupId>
        <artifactId>micrometer-registry-prometheus</artifactId>
    </dependency>
</dependencies>
```

```bash
# application.properties snippet
# Expose the Prometheus endpoint
management.endpoints.web.exposure.include=prometheus
# Metrics available at http://host:port/actuator/prometheus
```

- **Java Debug Wire Protocol (JDWP)**: enables remote debugging. Use it only in dev and staging because **it carries significant performance overhead**.

```bash
# server=y (JVM running as debug server) 
# suspend=n (JVM does not wait for debugger to attach)
java -agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=*:8000 -jar myapp.jar
```


### Class Loading

Class loading defines how Java **bytecode** becomes executable within the JVM. Each class is loaded into memory once per `ClassLoader` instance and linked to its dependencies before execution.

#### Class Loader Hierarchy

- The JVM uses a delegation model with three main loaders. Each class loader first delegates the loading request to its parent before attempting to load the class itself.
1. **Bootstrap Class Loader** – Loads core Java classes from the `rt.jar` or `lib/modules`.
2. **Platform (Extension) Class Loader** – Loads platform-specific or optional system libraries like `/lib/ext` or modules.
3. **Application Class Loader** – Loads classes from CLASSPATH or app jars. Example source include `/app/classes` and `/libs/*.jar`.

- **Custom class loader**s can be implemented by extending `ClassLoader` to dynamically load classes from specific sources (for example, network, encrypted storage, or modular runtime systems).

```java
public class ClassLoaderHierarchy {
    public static void main(String[] args) {
        ClassLoader appLoader = ClassLoaderHierarchy.class.getClassLoader();
        System.out.println("Application ClassLoader: " + appLoader);
        System.out.println("Parent (Platform): " + appLoader.getParent());
        System.out.println("Grandparent (Bootstrap): " + appLoader.getParent().getParent());
    }
}
/* 
Application ClassLoader: jdk.internal.loader.ClassLoaders$AppClassLoader@63947c6b
Parent (Platform): jdk.internal.loader.ClassLoaders$PlatformClassLoader@37a71e93
Grandparent (Bootstrap): null
*/
```
- A `null` parent means the Bootstrap ClassLoader is implemented in native code, not a Java object.

#### Class Loading Process

1. **Loading** – The class bytecode is read into JVM memory (`ClassLoader.defineClass()`).
2. **Linking** – The JVM verifies, prepares, and optionally resolves symbolic references to other classes.
3. **Initialization** – Static blocks and static variable initializations are executed.

```java
public class LifecycleDemo {
    static { // runs automatically once, when class first loaded, before any method executes
        System.out.println("Static init block executed");
    }

    public static void main(String[] args) throws Exception {
        // Dynamically loads class name, triggers static block if not loaded
        Class<?> clazz = Class.forName("LifecycleDemo");
        System.out.println("Class loaded: " + clazz.getName());
    }
} // Class.forName() triggers both loading and initialization
```

- Memory leaks can happen when framework based systems (Spring Boot, plugins, etc) are loaded dynamically without class loaders being properly released.


#### Performance and Security Concerns

- **Lazy Loading**: Classes are only loaded when first referenced, reducing initial startup time.
- **Caching** / **Pools**: Once loaded, classes stored in memory for reuse. Frequent class reloading can be expensive in reflection-heavy frameworks (like **Spring** or **Hibernate**). Tune `ClassLoader` hierarchies and leverage class reuse where possible.
- **Metaspace Management**: Since Java 8, class metadata resides in Metaspace, which is limited by native system memory, NOT by default to the JVM heap. Tune using `-XX:MaxMetaspaceSize=<size>` to prevent unbounded growth by setting an explicit upper bound.

```bash
# Identify metaspace growth over time where dynamic reloading occurs especially
jcmd <pid> VM.native_memory summary
```

- **Security**: Validate class sources to prevent class **spoofing** or **malicious class substitution** - which is loading a class from an untrusted source instead of a legit system class.
    - **Secure ClassLoader Implementation**: Custom class loaders must STRICLY enforce the delegation model (parent first) and restrict where they look for classes (only validated, signed JAR files).
    - **Digital Signatures**: Checking the signature of JAR files ensures classes have not been tampered with.
    - **Serialization Filtering**: Insecure deserialization can occur when an attacker provides malicious byte stream to the app. Use Filtering (since Java 9) to validate incoming streams by inspecting class references.

## Existing Product Debugging

### Remote Debugging

- Production Remote Debugging Decision Matrix:

| Scenario| Recommended Approach| Rationale| 
|---------|--------------------|-----------|
| **Intermittent 500 errors**| JFR + structured logs| JDWP too invasive; JFR captures context without blocking| 
| **Memory leak suspected**| Heap dump analysis| One-time snapshot, minimal disruption| 
| **CPU spike investigation**| Thread dumps (3-5 samples) + async-profiler| Identifies hot threads without code-level debugging| 
| **Race condition**| BTrace or dynamic instrumentation| Add tracing to suspect code paths without restart| 
| **Startup failure**| JDWP with `suspend=y` in staging| Safe for pre-prod; captures initialization issues| 
| **Third-party library bug**| Decompile + source attach in staging| Never debug prod; reproduce in lower environment| 

#### Container Specific Debugging

- If your production pod lacks debugging tools:

```bash
# Attach a debug container with full KDJ to running pod
kubectl debug -it my-pod --image=openjdk:17-jdk --target=mydebugcontainer --share-processes

# Inside debug, all processes are visible
ps aux | grep java
jstack <pid> > /tmp/threaddump.txt
```

- Deploy Async-profiler as sidecar for **zero-restart profiling**:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: myapp
spec:
  shareProcessNamespace: true  # Critical: allows sidecar to see app process
  containers:
  - name: app
    image: myapp:latest
    
  - name: profiler
    image: async-profiler-sidecar:latest
    command: ["/bin/sh", "-c"]
    args:
    - |
      while true; do
        # Find Java process PID
        PID=$(pgrep -f 'java.*myapp')
        # Profile for 60s every 5 minutes
        /opt/async-profiler/profiler.sh -d 60 -f /shared/flamegraph-$(date +%s).svg $PID
        sleep 300
      done
    volumeMounts:
    - name: shared-data
      mountPath: /shared
  volumes:
  - name: shared-data
    emptyDir: {}
```

- Build a debug-enabled Dockerfile for staging:

```dockerfile
# Production image (final if built normally)
# JRE base image has smaller footprint
FROM eclipse-temurin:17-jre-alpine AS prod
COPY app.jar /app.jar
ENTRYPOINT ["java", "-jar", "/app.jar"]

# Debug Variant for staging
FROM eclipse-temurin:17-jdk-alpine AS debug
RUN apk add --no-cache curl jq
# Enable JMX, JFR, and async-profiler compatibility
ENV JAVA_TOOL_OPTIONS="-Dcom.sun.management.jmxremote \
    -Dcom.sun.management.jmxremote.port=9010 \
    -Dcom.sun.management.jmxremote.authenticate=false \
    -Dcom.sun.management.jmxremote.ssl=false \
    -XX:+UnlockDiagnosticVMOptions \
    -XX:+DebugNonSafepoints"
ENTRYPOINT ["java", "-jar", "/app.jar"]
# docker build --target prod -t myapp:prod .
# docker build --target debug -t myapp:debug .
```

#### Advanced Heap Dump Workflow

- Automated Heap Dump on OOM with Upload:

```bash
# JVM flags for automatic dump + script execution
-XX:+HeapDumpOnOutOfMemoryError \
-XX:HeapDumpPath=/tmp/heap.hprof \
-XX:OnOutOfMemoryError="sh /scripts/upload-heap.sh %p"
```

```bash
#!/bin/bash
# upload-heap.sh
PID=$1
TIMESTAMP=$(date +%Y%m%d=%H%M%S)
HEAP_FILE="/tmp/heap.hprof"
S3_BUCKET="s3://mycompany-heap-dumps"

# Compress (Heap dumps are HIGHLY compressable)
gzip $HEAP_FILE

aws s3 cp ${HEAP_FILE}.gz ${S3_BUCKET}/heap-${PID}-${TIMESTAMP}.hprof.gz \
    --metadata "pod=$HOSTNAME,timestamp=$TIMESTAMP"

# Cleanup
rm ${HEAP_FILE}.gz

# Alert SRE Team
curl -X POST https://slack-webhook-url \
    -d "{\"text\":\"OOM dump uploaded: ${S3_BUCKET}/heap-${PID}-${TIMESTAMP}.hprof.g\"}"
```

- Analyze Heap Dump with Eclipse MAT ( or `jhat` )

```bash
# Download Eclipse MAT standalone
wget https://eclipse.dev/mat/downloads.php
# Run headless for leak suspects
./mat/ParseHeapDump.sh heap.hprof org.eclipse.mat.api:suspects
# Generates HTML report with top memory consumers
# Start jhat server on http://localhost:7000
jhat -J-Xmx4g heap.hprof
```

#### BTrace Bytecode Instrumentation

1. Trace slow methods without modifying code. Designed to be non-intrusive and generally ok for production:

```java
import org.openjdk.btrace.core.annotations.*;
import static org.openjdk.btrace.core.BTraceUtils.*;

@BTrace // Declares class as BTrace script
public class SlowMethodTracer {

    @OnMethod(
        clazz="com.example.OrderService",
        method="/.*/", // All Methods of OrderService
        location=@Location(Kind.RETURN)
    )
    public static void onMethodReturn(
        @ProbeClassName String className,
        @ProbeMethodName String methodName,
        @Duration long durationNs) {

        if (durationNs > 100_000_000L) { // 100ms
            println(strcat(strcat(className, "."), methodName));
            println(strcat("Duration (ms): ", str(durationNs / 1_000_000)));
        }
    }
}
```

2. Capture Method Arguments on **Exception**:

```java
@BTrace
public class ExceptionArgumentTracer {
    
    @OnMethod( // specify target classes/method/location
        clazz="com.example.PaymentService",
        method="processPayment",
        location=@Location(Kind.ERROR)
    )
    public static void onException(
        @ProbeClassName String className,
        @ProbeMethodName String methodName,
        String userId,
        double amount,
        @Return Throwable exception) {
        
        println("=== Payment Failure ===");
        println(strcat("User: ", userId));
        println(strcat("Amount: ", str(amount)));
        println(strcat("Exception: ", str(exception)));
    }
}
```

3. Monitor Object Allocation Hotspots

```java
@BTrace
public class AllocationTracker {

    @OnMethod(
        clazz="+com.example.model.*", // All classes in package
        method="<init>" // Constructor
    )
    public static void onObjectCreate(@ProbeClassName String className) {
        println(strcat("Created: ", className));
    }
}
```

4. Attach BTrace to Running Process:

```bash
# Compile BTrace script
btracec SlowMethodTracer.java
# Attach to process (Creates no GC pressure)
btrace <pid> SlowMethodTracer.class
# Output streams to console in real-time, cancel with CTL+C
```

#### JMX Monitoring in Kubernetes

- Expose JMX Securely via Port-forward:

```bash
# App must have JMX enabled with:
# -Dcom.sun.management.jmxremote.port=9010
# -Dcom.sun.management.jmxremote.authenticate=false (staging only)
kubectl port-forward <pod> 9010:9010 # localhostport:containerport
#Connect Jconsole to localhost:9010
jconsole localhost:9010
```

- JMX Exporter for Prometheus:

```yaml
# Configmap with JMX exporter config
apiVersion: v1
kind: ConfigMap
metadata:
  name: jmx-exporter-config
data:
  config.yml: | # Configuration file content for JMX exporter
    rules:
    - pattern: 'java.lang<type=Memory><HeapMemoryUsage>(\w+)' # Match heap memory stats
      name: jvm_memory_heap_$1 # Metric name template for prometheus
      type: GAUGE
    - pattern: 'java.lang<type=GarbageCollector, name=(\w+)><CollectionCount>'
      name: jvm_gc_collection_count
      labels:
        gc: $1
---
apiVersion: apps/v1
kind: Deployment
spec:
  template:
    spec:
      containers:
      - name: app
        image: myapp:latest # your java app with NO built-in JMX exporter
        env:
        - name: JAVA_TOOL_OPTIONS # Attach JMX exporter as javaagent on port 8080 with above config
          value: "-javaagent:/jmx-exporter/jmx_prometheus_javaagent.jar=8080:/config/config.yml"
        volumeMounts: # Mount empty dir volume to hold JMX exporter jar after download
        - name: jmx-exporter
          mountPath: /jmx-exporter
        - name: config # Mount the ConfigMap volume containing config.yml
          mountPath: /config
      volumes:
      - name: jmx-exporter
        emptyDir: {} # Temp storage volume emptied on pod restart
      - name: config
        configMap:
          name: jmx-exporter-config # Mount ConfigMap as volume to read config.yml
      initContainers:
      - name: download-jmx-exporter
        image: curlimages/curl/latest # used to curl the JMX exporter jar
        command:
        - sh
        - -c
        - |
          curl -L -o /jmx-exporter/jmx_prometheus_javaagent.jar \
          https://repo1.maven.org/maven2/io/prometheus/jmx/jmx_prometheus_javaagent/0.20.0/jmx_prometheus_javaagent-0.20.0.jar
        volumeMounts:
        - name: jmx-exporter # Share same volume as main container so its available on startup
          mountPath: /jmx-exporter
```

- Query JMX Metrics via Prometheus:

```promql
# Heap usage percentage
100 * jvm_memory_heap_used / jvm_memory_heap_max
# GC frequency (collections per second)
rate(jvm_gc_collection_count[5m])
# Alert on high GC time percentage
(rate(jvm_gc_collection_time_seconds[5m]) / rate(jvm_gc_collection_count[5m])) > 0.5
```

### Logging Frameworks

- Log Level Strategy for Production

| Level| Purpose| Example Use Cases| Production Volume| 
|--------|-------|-----------|--------------|
| `TRACE`| Extremely detailed flow (line-by-line)| **Never TRACE in production**; dev debugging only| `0%`| 
| `DEBUG`| Detailed diagnostic info| **Enabled temporarily** for specific packages during incidents| `<1%`| 
| `INFO`| Significant and meaningful business events| User login, order placed, payment processed| `60-80%`| 
| `WARN`| Recoverable issues, degraded state, spot anomalies| Retry attempts, fallback to cache, deprecated API usage| `15-30%`| 
| `ERROR`| Failures requiring attention| Unhandled exceptions, external service failures| `5-10%`| 


- Production `logback-spring.xml`:

```xml
<!-- logback-spring.xml -->
<configuration>
    <springProfile name="production">
        <root level="INFO">
            <appender-ref ref="ASYNC_JSON_CONSOLE"/>
            <appender-ref ref="ERROR_FILE"/>
        </root>
        
        <!-- Silence noisy frameworks -->
        <logger name="org.springframework.web" level="WARN"/>
        <logger name="org.hibernate.engine.internal" level="WARN"/>
        <logger name="com.zaxxer.hikari" level="WARN"/>
        
        <!-- Amplify critical paths (enable via runtime flag) -->
        <logger name="com.example.payment" level="${PAYMENT_LOG_LEVEL:-INFO}"/>
        <logger name="com.example.fraud" level="${FRAUD_LOG_LEVEL:-INFO}"/>
    </springProfile>
</configuration>
```

#### Mapped Diagnositc Context (MDC)

- Trace ID Propagation across microservices:

```java
import org.slf4j.MDC;
import java.util.UUID;

@Component
public class TraceFilter extends OncePerRequestFilter {

    private static final String TRACE_ID = "traceId";
    private static final String SPAN_ID = "spanId";

    @Override
    protected void doFilterInternal(HttpServletRequest request,
                                    HttpServletResponse response,
                                    FilterChain chain) throws IOException, ServletException {
        try {
            //Extract or Generate trace ID
            String traceID = request.getHeader("X-Trace-Id");
            if (traceId == null) {
                traceId = UUID.randomUUID().toString();
            }

            String spanId = UUID.randomUUID().toString();

            // Add to MDC (thread-local)
            MDC.put(TRACE_ID, traceId);
            MDC.put(SPAN_ID, spanId);

            // Propagate donwstream
            response.setHeader("X-Trace-Id", traceId);

            chain.doFilter(request, response);
        } finally {
            // ALWAYS clear MDC to prevent memory leaks!
            MDC.clear
        }
    }
}
```

- MDC in Async/ThreadPool Contexts (maintaining contextual information across thread boundaries during async execution):

```java
import org.slf4j.MDC; // Store contextual logging in thread-local
import java.util.Map; // Java Map interface for key-value pairs
import java.util.concurrent.Callable;

// custom task decorator, Springs TaskDecorator, Decorate async tasks (Runnable)
public class MDCTaskDecorator implements TaskDecorator {

    // Returned Runnable sets this captured MDC context into worker
    @Override
    public Runnable decorate(Runnable task) {
        // Capture MDC from parent thread (where task was submitted)
        Map<String, String> contextMap = MDC.getCopyOfContextMap();

        // Return a new Runnable that wraps the original task
        return () -> {
            try {
                // Restore MDC in worker thread
                if (contextMap != null) {
                    MDC.setContextMap(contextMap);
                }
                task.run(); // Run the actual task after adding the context
            } finally {
                MDC.clear()
            }
        };
    }
}
// Spring config to register task executor with the MDC-propagting task decorator
@Configuration
public class AsyncConfig {

    // Without this propagation, async threads lose context (like trace-id) making logging difficult
    @Bean
    public ThreadPoolTaskExecutor taskExecutor() {
        ThreadPoolTaskExecutor executor = new ThreadPoolTaskExecutor();
        executor.setCorePoolSize(10);
        executor.setMaxPoolSize(50);
        // Register the custom decorator to copy MDC context to async threads
        executor.setTaskDecorator(new MDCTaskDecorator()); // Enables MDC propagation
        return executor;
    }
}
// You run the methods/tasks asyncly or concurrently by submitting the Runnable or Callable task to the above excecutor
```

- Structured JSON log format with MDC fields in `src/main/resources/logback-spring.xml`:

```xml
<appender name="JSON_CONSOLE" class="ch.qos.logback.core.ConsoleAppender">
    <encoder class="net.logstash.logback.encoder.LogstashEncoder">
        <customFields>{"service":"order-service","environment":"${ENV:production}"}</customFields>
        
        <!-- MDC fields automatically included -->
        <includeMdcKeyName>traceId</includeMdcKeyName>
        <includeMdcKeyName>spanId</includeMdcKeyName>
        <includeMdcKeyName>userId</includeMdcKeyName>
        
        <!-- Structured arguments -->
        <includeStructuredArguments>true</includeStructuredArguments>
    </encoder>
</appender>
```

- SLF4J Structured Logging in Application Code:

```java
// This static import allows you to use kv() and v() directly
import static net.logstash.logback.argument.StructuredArguments.*;

// Logback's integration with SLF4J and MDC for advanced/structured logging
public class OrderService {
    private static final Logger log = LoggerFactory.getLogger(OrderService.class);
    
    public void placeOrder(Order order) {
        // Add user context to MDC
        MDC.put("userId", order.getUserId());
        MDC.put("orderId", order.getId());
        
        try {
            // Structured logging with key-value pairs
            log.info("Order placement started",
                kv("orderId", order.getId()),
                kv("amount", order.getTotalAmount()),
                kv("itemCount", order.getItems().size()));
            
            processPayment(order);
            
            log.info("Order placed successfully",
                kv("orderId", order.getId()),
                kv("processingTimeMs", order.getProcessingTime()));
                
        } catch (PaymentException e) {
            log.error("Payment failed",
                kv("orderId", order.getId()),
                kv("paymentMethod", order.getPaymentMethod()),
                kv("errorCode", e.getErrorCode()),
                e);
        } finally {
            MDC.remove("userId");
            MDC.remove("orderId");
        }
    }
}
```

- The resulting JSON log:

```json
{
  "timestamp": "2025-10-31T14:23:45.123Z",
  "level": "INFO",
  "service": "order-service",
  "environment": "production",
  "traceId": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "spanId": "x9y8z7w6-v5u4-3210-t9s8-r7q6p5o4n3m2",
  "userId": "user-12345",
  "orderId": "order-67890",
  "thread": "http-nio-8080-exec-42",
  "logger": "com.example.OrderService",
  "message": "Order placement started",
  "orderId": "order-67890",
  "amount": 149.99,
  "itemCount": 3
}
```

#### Log Aggregation Query Patterns

- **ElasticSearch** Aggregate Error Counts by Service:

```json
// Aggregate error counts by service
GET /logs-*/_search
{
  "size": 0,
  "query": {"range": {"timestamp": {"gte": "now-1h"}}},
  "aggs": {
    "by_service": {
      "terms": {"field": "service.keyword"},
      "aggs": {
        "error_count": {
          "filter": {"term": {"level": "ERROR"}}
        }
      }
    }
  }
}
```

- Splunk Find Slow Transactions with alerts:

```spl
# Find slow transactions (>5s) with full trace
index=app_logs processingTimeMs>5000
| table timestamp, traceId, userId, orderId, processingTimeMs
| sort - processingTimeMs

# Alert query: Error rate spike
index=app_logs level=ERROR
| timechart span=5m count as errors
| where errors > 100
```

## Examples

### Troubleshooting

| Issue	|  Root Cause	| Diagnostic Command / Fix| 
|--------|--------------|-------------------------|
| `ClassNotFoundException`	| Missing JAR or wrong classpath	| Check `$JAVA_HOME`, `-cp`, or container volume mounts| 
| `NoClassDefFoundError`| 	Class found during compile, missing at runtime	| Verify module/classpath alignment| 
| `LinkageError` / `IncompatibleClassChangeError`	| Two versions of same class loaded by different classloaders	| Use `-verbose:class` or `jcmd` to trace| 
| **ClassLoader Leak**| 	Webapp redeployed without unloading classloader	| Monitor with `jmap -histo` or Eclipse MAT| 
| **Metaspace OOM**	| Unbounded class metadata growth	| Tune with `-XX:MaxMetaspaceSize=256m` and verify dynamic proxy usage| 
| **Slow Startup**	| Too many classes eagerly loaded	| Enable lazy loading, AOT compilation, or class data sharing| 

```bash
# Example Verbose Class Loading
# On K8, combine with startup probe or logging side cars to ID classes causing latency
java -verbose:class -jar app.jar
# Output:
#[Loaded java.lang.Object from /usr/lib/jvm/java-17/lib/modules]
#[Loaded com.example.MyService from file:/app/libs/my-service.jar]
```