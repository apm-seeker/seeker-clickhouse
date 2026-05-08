-- Kafka 엔진 소스 테이블.
-- collector 의 EventEnvelope { eventType, timestamp, payload } 구조를 그대로 받는다.
-- payload 는 모양이 eventType 별로 달라서 String 으로 두고 MV 에서 JSONExtract 로 파싱.
-- 이렇게 두면 collector 가 payload 에 필드를 추가해도 이 테이블은 손대지 않아도 된다.
-- input_format_json_read_objects_as_strings 가 켜져 있어야 collector 가 보내는
-- 중첩 JSON 객체(payload)를 String 컬럼에 raw text 그대로 적재할 수 있다.

-- trace-data 토픽: TRACE / SPAN / SPAN_EVENT
CREATE TABLE IF NOT EXISTS kafka_trace_data
(
    eventType LowCardinality(String),
    timestamp Int64,
    payload   String
)
ENGINE = Kafka
SETTINGS
    kafka_broker_list               = 'seeker-kafka:29092',
    kafka_topic_list                = 'trace-data',
    kafka_group_name                = 'clickhouse-trace-consumer',
    kafka_format                    = 'JSONEachRow',
    kafka_num_consumers             = 1,
    kafka_max_block_size            = 65536,
    kafka_skip_broken_messages      = 100,
    kafka_thread_per_consumer       = 1,
    input_format_import_nested_json           = 1,
    input_format_json_read_objects_as_strings = 1;

-- agent-events 토픽: AGENT_CREATED / AGENT_DELETED
CREATE TABLE IF NOT EXISTS kafka_agent_events
(
    eventType LowCardinality(String),
    timestamp Int64,
    payload   String
)
ENGINE = Kafka
SETTINGS
    kafka_broker_list               = 'seeker-kafka:29092',
    kafka_topic_list                = 'agent-events',
    kafka_group_name                = 'clickhouse-agent-consumer',
    kafka_format                    = 'JSONEachRow',
    kafka_num_consumers             = 1,
    kafka_max_block_size            = 65536,
    kafka_skip_broken_messages      = 100,
    kafka_thread_per_consumer       = 1,
    input_format_import_nested_json           = 1,
    input_format_json_read_objects_as_strings = 1;
