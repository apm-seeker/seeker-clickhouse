-- Materialized View: Kafka 엔진 테이블 → 저장 테이블로 fan-out.
-- WHERE eventType 으로 분기하므로 Kafka 토픽은 한 번만 읽힌다.
-- Nullable 컬럼은 JSONExtract(..., 'Nullable(...)') 로 받아 빈 문자열이 아니라 NULL 로 들어가게 한다.

-- ============================================================
-- trace-data → trace / span / span_event
-- ============================================================

CREATE MATERIALIZED VIEW IF NOT EXISTS mv_trace TO trace AS
SELECT
    JSONExtractString(payload, 'traceId')                          AS trace_id,
    fromUnixTimestamp64Milli(JSONExtractInt(payload, 'startTime')) AS start_time,
    JSONExtractInt(payload, 'elapsedTime')                         AS elapsed_time,
    JSONExtract(payload, 'url', 'Nullable(String)')                AS url,
    JSONExtract(payload, 'remoteAddress', 'Nullable(String)')      AS remote_address,
    JSONExtractInt(payload, 'statusCode')                          AS status_code
FROM kafka_trace_data
WHERE eventType = 'TRACE';

CREATE MATERIALIZED VIEW IF NOT EXISTS mv_span TO span AS
SELECT
    JSONExtractString(payload, 'traceId')                          AS trace_id,
    JSONExtractInt(payload, 'spanId')                              AS span_id,
    JSONExtractInt(payload, 'parentSpanId')                        AS parent_span_id,
    JSONExtract(payload, 'agentId', 'Nullable(String)')            AS agent_id,
    JSONExtract(payload, 'parentAgentId', 'Nullable(String)')      AS parent_agent_id,
    fromUnixTimestamp64Milli(JSONExtractInt(payload, 'startTime')) AS start_time,
    JSONExtractInt(payload, 'elapsedTime')                         AS elapsed_time,
    JSONExtract(payload, 'uri', 'Nullable(String)')                AS uri,
    JSONExtract(payload, 'remoteAddress', 'Nullable(String)')      AS remote_address,
    JSONExtract(payload, 'endPoint', 'Nullable(String)')           AS end_point,
    JSONExtractInt(payload, 'statusCode')                          AS status_code,
    JSONExtract(payload, 'exceptionInfo', 'Nullable(String)')      AS exception_info
FROM kafka_trace_data
WHERE eventType = 'SPAN';

CREATE MATERIALIZED VIEW IF NOT EXISTS mv_span_event TO span_event AS
SELECT
    JSONExtractInt(payload, 'spanId')                              AS span_id,
    JSONExtractInt(payload, 'sequence')                            AS sequence,
    JSONExtractInt(payload, 'depth')                               AS depth,
    fromUnixTimestamp64Milli(JSONExtractInt(payload, 'startTime')) AS start_time,
    JSONExtractInt(payload, 'elapsedTime')                         AS elapsed_time,
    JSONExtract(payload, 'className', 'Nullable(String)')          AS class_name,
    JSONExtract(payload, 'methodName', 'Nullable(String)')         AS method_name,
    JSONExtract(payload, 'exceptionInfo', 'Nullable(String)')      AS exception_info,
    JSONExtract(payload, 'attributes', 'Map(String, String)')      AS attributes
FROM kafka_trace_data
WHERE eventType = 'SPAN_EVENT';

-- ============================================================
-- agent-events → agent
-- ============================================================

CREATE MATERIALIZED VIEW IF NOT EXISTS mv_agent_created TO agent AS
SELECT
    JSONExtractString(payload, 'agentId')                          AS agent_id,
    'CREATED'                                                      AS event_type,
    fromUnixTimestamp64Milli(JSONExtractInt(payload, 'startTime')) AS event_time,
    JSONExtract(payload, 'agentName', 'Nullable(String)')          AS agent_name,
    JSONExtract(payload, 'agentType', 'Nullable(String)')          AS agent_type,
    JSONExtract(payload, 'agentGroup', 'Nullable(String)')         AS agent_group
FROM kafka_agent_events
WHERE eventType = 'AGENT_CREATED';

CREATE MATERIALIZED VIEW IF NOT EXISTS mv_agent_deleted TO agent AS
SELECT
    JSONExtractString(payload, 'agentId')                        AS agent_id,
    'DELETED'                                                    AS event_type,
    fromUnixTimestamp64Milli(JSONExtractInt(payload, 'endTime')) AS event_time,
    CAST(NULL AS Nullable(String))                               AS agent_name,
    CAST(NULL AS Nullable(String))                               AS agent_type,
    CAST(NULL AS Nullable(String))                               AS agent_group
FROM kafka_agent_events
WHERE eventType = 'AGENT_DELETED';

-- ============================================================
-- metric → metric (snapshot.points[] 를 ARRAY JOIN 으로 row 단위 fan-out)
-- ============================================================

CREATE MATERIALIZED VIEW IF NOT EXISTS mv_metric TO metric AS
SELECT
    JSONExtractString(payload, 'applicationName')                  AS application_name,
    JSONExtractString(payload, 'agentId')                          AS agent_id,
    fromUnixTimestamp64Milli(JSONExtractInt(payload, 'timestamp')) AS timestamp,
    JSONExtractInt(payload, 'collectIntervalMs')                   AS collect_interval_ms,
    point.1                                                        AS metric_name,
    point.2                                                        AS field_name,
    point.3                                                        AS value,
    point.4                                                        AS type,
    point.5                                                        AS tags
FROM kafka_metric
ARRAY JOIN JSONExtract(
    payload, 'points',
    'Array(Tuple(metricName String, fieldName String, value Float64, type String, tags Map(String, String)))'
) AS point
WHERE eventType = 'METRIC_SNAPSHOT';
