from kafka import KafkaConsumer, TopicPartition
from kafka.errors import KafkaError
import json
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class MessageConsumer:
    def __init__(self, bootstrap_servers, group_id, topics):
        self.consumer = KafkaConsumer(
            *topics,
            bootstrap_servers=bootstrap_servers,
            group_id=group_id,
            value_deserializer=lambda m: json.loads(m.decode('utf-8')),
            key_deserializer=lambda k: k.decode('utf-8') if k else None,
            auto_offset_reset='earliest',  # or 'latest'
            enable_auto_commit=False,  # Manual commit for reliability
            max_poll_records=500,
            session_timeout_ms=30000,
            heartbeat_interval_ms=10000
        )
    
    def consume_messages(self, process_func):
        """Consume messages with manual commit"""
        try:
            for message in self.consumer:
                logger.info(
                    f"Received: topic={message.topic} "
                    f"partition={message.partition} "
                    f"offset={message.offset} "
                    f"key={message.key}"
                )
                
                try:
                    # Process message
                    process_func(message.value)
                    
                    # Commit offset after successful processing
                    self.consumer.commit()
                    
                except Exception as e:
                    logger.error(f"Failed to process message: {e}")
                    # Handle error (retry, dead letter queue, etc.)
                    
        except KeyboardInterrupt:
            logger.info("Consumer interrupted")
        finally:
            self.close()
    
    def consume_batch(self, process_batch_func, batch_size=100):
        """Consume messages in batches"""
        try:
            batch = []
            for message in self.consumer:
                batch.append(message)
                
                if len(batch) >= batch_size:
                    try:
                        process_batch_func([m.value for m in batch])
                        self.consumer.commit()
                        batch = []
                    except Exception as e:
                        logger.error(f"Failed to process batch: {e}")
                        
        except KeyboardInterrupt:
            logger.info("Consumer interrupted")
        finally:
            if batch:
                try:
                    process_batch_func([m.value for m in batch])
                    self.consumer.commit()
                except Exception as e:
                    logger.error(f"Failed to process final batch: {e}")
            self.close()
    
    def seek_to_timestamp(self, timestamp_ms):
        """Seek to specific timestamp across all partitions"""
        partitions = self.consumer.assignment()
        timestamps = {p: timestamp_ms for p in partitions}
        offsets = self.consumer.offsets_for_times(timestamps)
        
        for partition, offset_and_timestamp in offsets.items():
            if offset_and_timestamp:
                self.consumer.seek(partition, offset_and_timestamp.offset)
    
    def close(self):
        self.consumer.close()

# Usage
def process_message(message):
    logger.info(f"Processing: {message}")
    # Your processing logic here

if __name__ == "__main__":
    consumer = MessageConsumer(
        bootstrap_servers=['localhost:9092'],
        group_id='my-consumer-group',
        topics=['user-events']
    )
    
    consumer.consume_messages(process_message)