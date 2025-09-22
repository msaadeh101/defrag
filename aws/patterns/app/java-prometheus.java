@Configuration
@EnableConfigurationProperties(MetricsProperties.class)
public class MetricsConfiguration {

    @Bean
    public MeterRegistryCustomizer<MeterRegistry> metricsCommonTags(
            @Value("${spring.application.name}") String applicationName,
            @Value("${ENVIRONMENT:local}") String environment) {
        return registry -> registry.config()
                .commonTags(
                        "application", applicationName,
                        "environment", environment,
                        "region", System.getenv("AWS_REGION")
                );
    }

    @Bean
    public TimedAspect timedAspect(MeterRegistry registry) {
        return new TimedAspect(registry);
    }

    @Bean
    @ConditionalOnMissingBean
    public Counter httpRequestCounter(MeterRegistry registry) {
        return Counter.builder("http_requests_total")
                .description("Total HTTP requests")
                .register(registry);
    }

    @Bean
    @ConditionalOnMissingBean
    public Timer databaseTimer(MeterRegistry registry) {
        return Timer.builder("database_operation_duration")
                .description("Database operation duration")
                .register(registry);
    }
}

@Component
public class CustomMetrics {
    
    private final Counter businessOperationCounter;
    private final Timer businessOperationTimer;
    private final Gauge activeConnectionsGauge;
    
    public CustomMetrics(MeterRegistry meterRegistry) {
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
    
    public void incrementBusinessOperation(String operationType) {
        businessOperationCounter.increment(Tags.of("type", operationType));
    }
    
    public Timer.Sample startBusinessOperation() {
        return Timer.start(businessOperationTimer);
    }
    
    private double getActiveConnections() {
        // Implementation to get active connections
        return 0.0;
    }
}