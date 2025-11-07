#!/bin/bash
# kafka_benchmark.sh - Comprehensive performance test
# ./kafka_benchmark.sh "my-broker:9092" "custom-topic"

# Ensure script failes at first error and exits with meaninful output
set -euo pipefail
trap 'echo "Error occurred. Exiting."; exit 1' ERR

BOOTSTRAP="${1:-broker1:9092,broker2:9092,broker3:9092}"
TOPIC="${2:-benchmark-test}"

RESULTS_DIR="benchmark_results_$(date +%Y%m%d_%H%M%S)"

mkdir -p "$RESULTS_DIR"

echo "=== Kafka Performance Benchmark ==="
echo "Bootstrap: $BOOTSTRAP"
echo "Topic: $TOPIC"
echo ""

# Create test topic
echo "Creating test topic..."
kafka-topics.sh --bootstrap-server "$BOOTSTRAP" \
  --create --if-not-exists \
  --topic "$TOPIC" \
  --partitions 12 \
  --replication-factor 3 \
  --config retention.ms=3600000

# Producer tests
echo ""
echo "=== Producer Benchmarks ==="

# Test 1: Throughput test (no acks)
echo ""
echo "[1] Maximum throughput (acks=0)..."
kafka-producer-perf-test.sh \
  --topic "$TOPIC" \
  --num-records 5000000 \
  --record-size 1024 \
  --throughput -1 \
  --producer-props \
    bootstrap.servers="$BOOTSTRAP" \
    acks=0 \
    compression.type=lz4 \
    batch.size=32768 \
    linger.ms=10 \
  | tee "$RESULTS_DIR/producer_max_throughput.txt"

# Test 2: Durable throughput (acks=all)
echo ""
echo "[2] Durable throughput (acks=all)..."
kafka-producer-perf-test.sh \
  --topic "$TOPIC" \
  --num-records 5000000 \
  --record-size 1024 \
  --throughput -1 \
  --producer-props \
    bootstrap.servers="$BOOTSTRAP" \
    acks=all \
    compression.type=lz4 \
    batch.size=32768 \
    linger.ms=10 \
  | tee "$RESULTS_DIR/producer_durable_throughput.txt"

# Test 3: Latency test (small batches)
echo ""
echo "[3] Low latency (small batches)..."
kafka-producer-perf-test.sh \
  --topic "$TOPIC" \
  --num-records 100000 \
  --record-size 1024 \
  --throughput 10000 \
  --producer-props \
    bootstrap.servers="$BOOTSTRAP" \
    acks=1 \
    compression.type=none \
    batch.size=0 \
    linger.ms=0 \
  | tee "$RESULTS_DIR/producer_low_latency.txt"

# Test 4: Various message sizes
for size in 100 1024 10240 102400; do
  echo ""
  echo "[4] Message size: $size bytes..."
  kafka-producer-perf-test.sh \
    --topic "$TOPIC" \
    --num-records 1000000 \
    --record-size $size \
    --throughput -1 \
    --producer-props \
      bootstrap.servers="$BOOTSTRAP" \
      acks=all \
      compression.type=lz4 \
    | tee "$RESULTS_DIR/producer_size_${size}.txt"
done

# Consumer tests
echo ""
echo "=== Consumer Benchmarks ==="

# Test 5: Consumer throughput
echo ""
echo "[5] Consumer throughput..."
kafka-consumer-perf-test.sh \
  --bootstrap-server "$BOOTSTRAP" \
  --topic "$TOPIC" \
  --messages 5000000 \
  --threads 4 \
  --fetch-size 1048576 \
  --reporting-interval 1000 \
  | tee "$RESULTS_DIR/consumer_throughput.txt"

# Test 6: Consumer with different fetch sizes
for fetch_size in 102400 524288 1048576 5242880; do
  echo ""
  echo "[6] Consumer fetch size: $fetch_size..."
  kafka-consumer-perf-test.sh \
    --bootstrap-server "$BOOTSTRAP" \
    --topic "$TOPIC" \
    --messages 1000000 \
    --threads 1 \
    --fetch-size $fetch_size \
    | tee "$RESULTS_DIR/consumer_fetch_${fetch_size}.txt"
done

# End-to-end latency
echo ""
echo "=== End-to-End Latency ==="
echo ""
echo "[7] E2E latency test..."
kafka-run-class.sh kafka.tools.EndToEndLatency \
  "$BOOTSTRAP" \
  "$TOPIC" \
  10000 \
  1 \
  1024 \
  | tee "$RESULTS_DIR/e2e_latency.txt"

# Cleanup
echo ""
echo "Cleaning up test topic..."
kafka-topics.sh --bootstrap-server "$BOOTSTRAP" \
  --delete --topic "$TOPIC"

echo ""
echo "=== Benchmark Complete ==="
echo "Results saved to: $RESULTS_DIR"

# Generate summary
cat > "$RESULTS_DIR/summary.txt" <<EOF
Kafka Performance Benchmark Summary
===================================
Date: $(date)
Bootstrap: $BOOTSTRAP
Topic: $TOPIC (12 partitions, RF=3)

Producer Tests:
1. Max Throughput (acks=0):     $(grep "records/sec" "$RESULTS_DIR/producer_max_throughput.txt" | head -1)
2. Durable Throughput (acks=all): $(grep "records/sec" "$RESULTS_DIR/producer_durable_throughput.txt" | head -1)
3. Low Latency:                  $(grep "records/sec" "$RESULTS_DIR/producer_low_latency.txt" | head -1)

Consumer Tests:
5. Consumer Throughput:          $(grep "MB/sec" "$RESULTS_DIR/consumer_throughput.txt" | tail -1)

End-to-End Latency:
7. Average Latency:              $(grep "Avg latency" "$RESULTS_DIR/e2e_latency.txt")
EOF

cat "$RESULTS_DIR/summary.txt"