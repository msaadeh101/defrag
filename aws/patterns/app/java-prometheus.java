@Configuration // Spring Config Class, the source of bean (object) definitions
@EnableConfigurationProperties(MetricsProperties.class) // Load metric related properties
public class MetricsConfiguration {
// Registers beans ("services" or singletons) for metric tags, timers, counters

    @Bean // Exposes a reusable monitoring function (Spring bean)
    public MeterRegistryCustomizer<MeterRegistry> metricsCommonTags(
            @Value("${spring.application.name}") String applicationName, // Reads string env/config
            @Value("${ENVIRONMENT:local}") String environment) { // Reads env with default "local"
        return registry -> registry.config()
        // Adds default tags to all metrics: app name, environment, AWS region (from env)
                .commonTags(
                        "application", applicationName,
                        "environment", environment,
                        "region", System.getenv("AWS_REGION")
                );
    }

    @Bean
    public TimedAspect timedAspect(MeterRegistry registry) {
        // Adds support for @Timed annotation to measure method execution duration
        return new TimedAspect(registry);
    }

    @Bean
    @ConditionalOnMissingBean // Only create if bean isn’t defined elsewhere
    public Counter httpRequestCounter(MeterRegistry registry) {
        // Exposes a counter metric for HTTP requests
        return Counter.builder("http_requests_total")
                .description("Total HTTP requests")
                .register(registry);
    }

    @Bean
    @ConditionalOnMissingBean // Only create if bean isn’t defined elsewhere
    public Timer databaseTimer(MeterRegistry registry) {
        // Exposes timer metric for DB operations
        return Timer.builder("database_operation_duration")
                .description("Database operation duration")
                .register(registry);
    }
}

@Component // Marks this for detection as a singleton
public class CustomMetrics {
    // Declare metrics as fields
    private final Counter businessOperationCounter;
    private final Timer businessOperationTimer;
    private final Gauge activeConnectionsGauge;
    
    public CustomMetrics(MeterRegistry meterRegistry) {
        // Initializes named metric objects during class construction

        this.businessOperationCounter = Counter.builder("business_operations_total")
                .description("Total business operations")
                .tag("type", "unknown")
                .register(meterRegistry);
                
        this.businessOperationTimer = Timer.builder("business_operation_duration")
                .description("Business operation duration")
                .register(meterRegistry);
                
        this.activeConnectionsGauge = Gauge.builder("active_connections")
                .description("Number of active connections")
                .register(meterRegistry, this, CustomMetrics::getActiveConnections);
    }
    
    // Increment the counter for a business operation (e.g. for each API call)
    public void incrementBusinessOperation(String operationType) {
        businessOperationCounter.increment(Tags.of("type", operationType));
    }
    
    // Start timing a business operation
    public Timer.Sample startBusinessOperation() {
        return Timer.start(businessOperationTimer);
    }
    
    // Get number of active connections (returns 0.0 here, stub for real value
    private double getActiveConnections() {
        // Implementation to get active connections
        return 0.0;
    }
}