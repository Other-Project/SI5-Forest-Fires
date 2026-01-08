use futures::StreamExt;
use log::{error, info, warn};
use rdkafka::{
    ClientConfig, Message,
    consumer::{Consumer, StreamConsumer},
    error::RDKafkaErrorCode,
};

pub fn setup_redpanda_consumer(brokers: String, group_id: String) -> StreamConsumer {
    ClientConfig::new()
        .set("group.id", &group_id)
        .set("bootstrap.servers", &brokers)
        .set("enable.partition.eof", "false")
        .set("session.timeout.ms", "6000")
        .set("enable.auto.commit", "false")
        .set("topic.metadata.refresh.interval.ms", "10000")
        .create()
        .expect("Consumer creation failed")
}

pub async fn subscribe_to_topic<F, Fut>(consumer: &StreamConsumer, topic: String, handler: F)
where
    F: Fn(rdkafka::message::OwnedMessage) -> Fut + Send + Sync + 'static,
    Fut: std::future::Future<Output = ()> + Send + 'static,
{
    consumer
        .subscribe(&[&topic])
        .expect("Can't subscribe to specified topic");

    let mut stream = consumer.stream();
    while let Some(message_result) = stream.next().await {
        match message_result {
            Ok(borrowed_message) => {
                info!("Message received at offset {}", borrowed_message.offset());
                let owned_message = borrowed_message.detach();
                let handler = &handler;
                tokio::spawn(handler(owned_message));
            }
            Err(e) => match e.rdkafka_error_code() {
                Some(RDKafkaErrorCode::UnknownTopicOrPartition) => {
                    warn!("Topic matching regex not found yet. Waiting...");
                }
                _ => {
                    error!("Error receiving message: {:?}", e);
                }
            },
        }
    }
}
