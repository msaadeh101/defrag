#!/usr/bin/env python3
# load_test.py - Advanced load testing

import time
import random
import json
import threading
from kafka import KafkaProducer, KafkaConsumer
from datetime import datetime
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class LoadTestProducer:
    def __init__(self, bootstrap_servers, topic, rate_per_second):
        self.producer = KafkaProducer(
            bootstrap_servers=bootstrap_servers,
            acks='all',
            compression_type='lz4',
            value_serializer=lambda v: json.dumps(v).encode('utf-8')
        )
        self.topic = topic
        self.rate_per_second = rate_per_second
        self.sent_count = 0
        self.error_count = 0
        self.lock = threading.Lock()
    
    def generate_message(self):
        return {
            'timestamp': datetime.utcnow().isoformat(),
            'user_id': random.randint(1, 10000),
            'event_type': random.choice(['view', 'click', 'purchase']),
            'value': random.uniform(0, 1000),
            'metadata': {
                'source': 'load_test',
                'version': '1.0'
            }
        }
    
    def send_callback(self, record_metadata):
        with self.lock:
            self.sent_count += 1
            if self.sent_count % 1000 == 0:
                logger.info(f"Sent {self.sent_count} messages")
    
    def error_callback(self, exception):
        with self.lock:
            self.error_count += 1
            logger.error(f"Error sending message: {exception}")
    
    def run(self, duration_seconds):
        start_time = time.time()
        interval = 1.0 / self.rate_per_second
        
        while time.time() - start_time < duration_seconds:
            message = self.generate_message()
            
            self.producer.send(
                self.topic,
                value=message
            ).add_callback(self.send_callback).add_errback(self.error_callback)
            
            time.sleep(interval)
        
        self.producer.flush()
        self.producer.close()
        
        logger.info(f"Load test complete: {self.sent_count} sent, {self.error_count} errors")


class LoadTestConsumer:
    def __init__(self, bootstrap_servers, topic, group_id):
        self.consumer = KafkaConsumer(
            topic,
            bootstrap_servers=bootstrap_servers,
            group_id=group_id,
            value_deserializer=lambda v: json.loads(v.decode('utf-8')),
            enable_auto_commit=False,
            max_poll_records=500
        )
        self.processed_count = 0
        self.latencies = []
    
    def run(self, duration_seconds):
        start_time = time.time()
        
        while time.time() - start_time < duration_seconds:
            messages = self.consumer.poll(timeout_ms=1000)
            
            for topic_partition, records in messages.items():
                for record in records:
                    # Calculate latency
                    msg_time = datetime.fromisoformat(record.value['timestamp'])
                    now = datetime.utcnow()
                    latency = (now - msg_time).total_seconds() * 1000  # ms
                    
                    self.latencies.append(latency)
                    self.processed_count += 1
            
            self.consumer.commit()
        
        self.consumer.close()
        
        if self.latencies:
            avg_latency = sum(self.latencies) / len(self.latencies)
            p50 = sorted(self.latencies)[len(self.latencies) // 2]
            p95 = sorted(self.latencies)[int(len(self.latencies) * 0.95)]
            p99 = sorted(self.latencies)[int(len(self.latencies) * 0.99)]
            
            logger.info(f"Processed {self.processed_count} messages")
            logger.info(f"Latency - Avg: {avg_latency:.2f}ms, P50: {p50:.2f}ms, "
                       f"P95: {p95:.2f}ms, P99: {p99:.2f}ms")


def run_load_test():
    BOOTSTRAP_SERVERS = ['broker1:9092', 'broker2:9092', 'broker3:9092']
    TOPIC = 'load-test'
    DURATION = 300  # 5 minutes
    RATE = 1000  # messages per second
    
    # Start consumer in background
    consumer_thread = threading.Thread(
        target=lambda: LoadTestConsumer(
            BOOTSTRAP_SERVERS, TOPIC, 'load-test-group'
        ).run(DURATION)
    )
    consumer_thread.start()
    
    # Run producer
    time.sleep(5)  # Let consumer initialize
    producer = LoadTestProducer(BOOTSTRAP_SERVERS, TOPIC, RATE)
    producer.run(DURATION)
    
    # Wait for consumer
    consumer_thread.join()


if __name__ == '__main__':
    run_load_test()