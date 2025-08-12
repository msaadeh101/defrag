from kafka import KafkaProducer
import json
import time

producer = KafkaProducer(
    bootstrap_servers=['localhost:9092'],
    key_serializer=lambda k: k.encode('utf-8'),
    value_serializer=lambda v: json.dumps(v).encode('utf-8'),
    acks='all',
    retries=3,
    compression_type='snappy',
    batch_size=16384,
    linger_ms=5
)

# Send message
event_data = {
    'user_id': 'user123',
    'event': 'login',
    'timestamp': int(time.time())
}

try:
    future = producer.send('user-events', key='user123', value=event_data)
    record_metadata = future.get(timeout=10)
    print(f"Message sent to partition {record_metadata.partition} offset {record_metadata.offset}")
except Exception as e:
    print(f"Error sending message: {e}")
finally:
    producer.close()