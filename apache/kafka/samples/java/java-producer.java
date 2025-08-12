import org.apache.kafka.clients.producer.*;
import java.util.Properties;

public class KafkaProducerExample {
    public static void main(String[] args) {
        Properties props = new Properties();
        props.put(ProducerConfig.BOOTSTRAP_SERVERS_CONFIG, "localhost:9092");
        props.put(ProducerConfig.KEY_SERIALIZER_CLASS_CONFIG, 
                  "org.apache.kafka.common.serialization.StringSerializer");
        props.put(ProducerConfig.VALUE_SERIALIZER_CLASS_CONFIG, 
                  "org.apache.kafka.common.serialization.StringSerializer");
        
        // Performance settings
        props.put(ProducerConfig.ACKS_CONFIG, "all");
        props.put(ProducerConfig.RETRIES_CONFIG, Integer.MAX_VALUE);
        props.put(ProducerConfig.ENABLE_IDEMPOTENCE_CONFIG, true);
        props.put(ProducerConfig.COMPRESSION_TYPE_CONFIG, "snappy");
        props.put(ProducerConfig.BATCH_SIZE_CONFIG, 16384);
        props.put(ProducerConfig.LINGER_MS_CONFIG, 5);

        Producer<String, String> producer = new KafkaProducer<>(props);
        
        try {
            ProducerRecord<String, String> record = 
                new ProducerRecord<>("user-events", "user123", 
                    "{\"event\":\"login\",\"timestamp\":1234567890}");
            
            producer.send(record, (metadata, exception) -> {
                if (exception != null) {
                    System.err.println("Error sending message: " + exception.getMessage());
                } else {
                    System.out.println("Sent message to partition " + metadata.partition() 
                                     + " with offset " + metadata.offset());
                }
            });
        } finally {
            producer.close();
        }
    }
}