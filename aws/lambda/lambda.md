# Lambda

## Introduction

AWS Lambda is an event-driven, serverless compute service that runs code in response to triggers, without provisioning or managing servers. It auto scales from a few requests per day to thousands per second. You ONLY pay for compute time consumed.

### Key Characteristics

- Event-Driven Execution:
- Stateless Ephemeral Execution:
- Automatic Scaling:
- Pay-Per-Use Billing:
- Managed Runtime:

### Lambda Execution Model

```txt
Request -> API Gateway/Event Source -> Lambda Service -> Execution Env -> VPC -> Response
```

### Considerations (Java)

- Cold start latency (mitigated with Java21+ and SnapStart).
- High Memory Footprint vs interpreted languages.
- Requires optimization for serverless context.

## Concepts and Topics

## Patterns

## Performance Optimization

## Security Best Practices

## Testing Strategies

## Monitoring and Observability