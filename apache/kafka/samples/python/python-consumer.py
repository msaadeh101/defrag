from kafka import KafkaConsumer
import json

consumer = KafkaConsumer(
    'user-events',
    bootstrap_servers=['localhost:9092'],
    group_id='user-event-processors',
    key_deserializer=lambda k: k.decode('utf-8'),
    value_deserializer=lambda v: json.loads(v.decode('utf-8')),
    auto_offset_reset='earliest',
    enable_auto_commit=False,
    max_poll_records=500
)

def process_event(event_data):
    """
    Process individual events with business logic.
    
    Common patterns include:
    - User authentication/session management 
    - Real-time analytics and metrics
    - Fraud detection and alerting
    - Data enrichment and transformation
    - Triggering downstream services/workflows
    """
    user_id = event_data.get('user_id')
    event_type = event_data.get('event')
    timestamp = event_data.get('timestamp')
    
    print(f"Processing {event_type} event for user {user_id} at {timestamp}")
    
    # Example business logic
    if event_type == 'purchase':
        # Trigger order fulfillment, update inventory, send confirmation email
        print(f"  → Initiating order fulfillment for {user_id}")
    elif event_type == 'login':
        # Update last login time, check for suspicious activity
        print(f"  → Updating user session for {user_id}")

try:
    for message in consumer:
        print(f"Consumed: partition={message.partition}, offset={message.offset}, "
              f"key={message.key}, value={message.value}")
        
        # Process message
        process_event(message.value)
        
        # Manual commit
        consumer.commit()

except KeyboardInterrupt:
    print("Consumer interrupted")
finally:
    consumer.close()