-- 저장 테이블 4종.
-- collector 의 Kafka 페이로드가 MV 를 통해 이 테이블들에 적재된다.

-- trace: HTTP 요청 단위 트레이스
CREATE TABLE IF NOT EXISTS trace
(
    trace_id        String,
    start_time      DateTime64(3),
    elapsed_time    Int32,
    url             Nullable(String),
    remote_address  Nullable(String),
    status_code     Int32,
    ingested_at     DateTime DEFAULT now()
)
ENGINE = MergeTree
PARTITION BY toYYYYMMDD(start_time)
ORDER BY (start_time, trace_id)
TTL toDateTime(start_time) + INTERVAL 30 DAY
SETTINGS index_granularity = 8192;

-- span: trace 내부의 호출 단위
CREATE TABLE IF NOT EXISTS span
(
    trace_id        String,
    span_id         Int64,
    parent_span_id  Int64,
    agent_id        Nullable(String),
    parent_agent_id Nullable(String),
    start_time      DateTime64(3),
    elapsed_time    Int32,
    uri             Nullable(String),
    remote_address  Nullable(String),
    end_point       Nullable(String),
    status_code     Int32,
    exception_info  Nullable(String),
    ingested_at     DateTime DEFAULT now()
)
ENGINE = MergeTree
PARTITION BY toYYYYMMDD(start_time)
ORDER BY (trace_id, span_id, start_time)
TTL toDateTime(start_time) + INTERVAL 30 DAY
SETTINGS index_granularity = 8192;

-- span_event: span 내부의 메서드/이벤트 시퀀스
CREATE TABLE IF NOT EXISTS span_event
(
    span_id         Int64,
    sequence        Int32,
    depth           Int32,
    start_time      DateTime64(3),
    elapsed_time    Int32,
    class_name      Nullable(String),
    method_name     Nullable(String),
    exception_info  Nullable(String),
    attributes      Map(String, String),
    ingested_at     DateTime DEFAULT now()
)
ENGINE = MergeTree
PARTITION BY toYYYYMMDD(start_time)
ORDER BY (span_id, sequence)
TTL toDateTime(start_time) + INTERVAL 30 DAY
SETTINGS index_granularity = 8192;

-- agent: agent 라이프사이클 이벤트 로그 (CREATED / DELETED)
CREATE TABLE IF NOT EXISTS agent
(
    agent_id    String,
    event_type  LowCardinality(String),
    event_time  DateTime64(3),
    agent_name  Nullable(String),
    agent_type  Nullable(String),
    agent_group Nullable(String),
    ingested_at DateTime DEFAULT now()
)
ENGINE = MergeTree
PARTITION BY toYYYYMM(event_time)
ORDER BY (agent_id, event_time)
SETTINGS index_granularity = 8192;

-- metric: 에이전트가 보낸 일반화 메트릭 (JVM, transaction, response_time 등)
-- collector 의 MetricSnapshot 한 건이 points[] 길이만큼 fan-out 되어 적재된다.
CREATE TABLE IF NOT EXISTS metric
(
    application_name    LowCardinality(String),
    agent_id            String,
    timestamp           DateTime64(3),
    collect_interval_ms Int64,
    metric_name         LowCardinality(String),
    field_name          LowCardinality(String),
    value               Float64,
    type                LowCardinality(String),
    tags                Map(String, String),
    ingested_at         DateTime DEFAULT now()
)
ENGINE = MergeTree
PARTITION BY toYYYYMMDD(timestamp)
ORDER BY (agent_id, metric_name, field_name, timestamp)
TTL toDateTime(timestamp) + INTERVAL 30 DAY
SETTINGS index_granularity = 8192;
