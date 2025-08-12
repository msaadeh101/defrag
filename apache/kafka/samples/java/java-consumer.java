import org.apache.kafka.clients.consumer.*;
import java.time.Duration;
import java.util.Arrays;
import java.util.Properties;

public class KafkaConsumerExample {
    public static void main(String[] args) {
        Properties props = new Properties();
        props.put(ConsumerConfig.BOOTSTRAP_SERVERS_CONFIG, "localhost:9092");
        props.put(ConsumerConfig.GROUP_ID_CONFIG, "user-event-processors");
        props.put(ConsumerConfig.KEY_DESERIALIZER_CLASS_CONFIG, 
                  "org.apache.kafka.common.serialization.StringDeserializer");
        props.put(ConsumerConfig.VALUE_DESERIALIZER_CLASS_CONFIG, 
                  "org.apache.kafka.common.serialization.StringDeserializer");
        
        // Consumer settings
        props.put(ConsumerConfig.AUTO_OFFSET_RESET_CONFIG, "earliest");
        props.put(ConsumerConfig.ENABLE_AUTO_COMMIT_CONFIG, false);
        props.put(ConsumerConfig.MAX_POLL_RECORDS_CONFIG, 500);
        props.put(ConsumerConfig.SESSION_TIMEOUT_MS_CONFIG, 30000);

        Consumer<String, String> consumer = new KafkaConsumer<>(props);
        consumer.subscribe(Arrays.asList("user-events"));

        try {
            while (true) {
                ConsumerRecords<String, String> records = consumer.poll(Duration.ofMillis(1000));
                
                for (ConsumerRecord<String, String> record : records) {
                    System.out.printf("Consumed message: key=%s, value=%s, partition=%d, offset=%d%n",
                            record.key(), record.value(), record.partition(), record.offset());
                    
                    // Process message here
                    processMessage(record.value());
                }
                
                // Manual commit after processing batch
                consumer.commitSync();
            }
        } finally {
            consumer.close();
        }
    }
    
    private static void processMessage(String message) {
        // Your processing logic here
        System.out.println("Processing: " + message);
    }
}