from kafka import KafkaProducer
from kafka.errors import KafkaError
import json
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class MessageProducer:
    def __init__(self, bootstrap_servers):
        self.producer = KafkaProducer(
            bootstrap_servers=bootstrap_servers,
            value_serializer=lambda v: json.dumps(v).encode('utf-8'),
            key_serializer=lambda k: k.encode('utf-8') if k else None,
            acks='all',  # Wait for all replicas
            retries=3,
            max_in_flight_requests_per_connection=1,  # Ensure ordering
            compression_type='snappy',
            linger_ms=10,  # Batch messages for 10ms
            batch_size=32768  # 32KB batch size
        )
    
    def send_message(self, topic, key, value):
        """Send message with callback handling"""
        try:
            future = self.producer.send(
                topic,
                key=key,
                value=value
            )
            
            # Block for 'synchronous' send
            record_metadata = future.get(timeout=10)
            
            logger.info(
                f"Message sent to {record_metadata.topic} "
                f"partition {record_metadata.partition} "
                f"offset {record_metadata.offset}"
            )
            return record_metadata
            
        except KafkaError as e:
            logger.error(f"Failed to send message: {e}")
            raise
    
    def send_batch(self, topic, messages):
        """Send multiple messages asynchronously"""
        futures = []
        for key, value in messages:
            future = self.producer.send(topic, key=key, value=value)
            futures.append(future)
        
        # Wait for all messages
        self.producer.flush()
        
        # Check results
        for future in futures:
            try:
                record_metadata = future.get(timeout=10)
                logger.info(f"Batch message sent: offset {record_metadata.offset}")
            except KafkaError as e:
                logger.error(f"Batch send failed: {e}")
    
    def close(self):
        self.producer.close()

# Usage
if __name__ == "__main__":
    producer = MessageProducer(['localhost:9092'])
    
    # Send single message
    producer.send_message(
        'user-events',
        key='user123',
        value={'event': 'login', 'timestamp': '2025-01-01T12:00:00Z'}
    )
    
    # Send batch
    messages = [
        ('user123', {'event': 'page_view', 'page': '/home'}),
        ('user456', {'event': 'purchase', 'amount': 99.99}),
    ]
    producer.send_batch('user-events', messages)
    
    producer.close()