# Design Decisions (BEAM/OTP)

Decisions specific to implementing the OpenTelemetry SDK on the BEAM VM. These are not part of the OTel specification but are required to map spec concepts to Erlang/OTP primitives.

Each decision links to related [compliance](compliance.md) items. When all linked compliance items are checked, the implementation for that decision is complete.

- Status: 🔲 not started / 🚧 in progress / ✅ done

## Phase 1: Traces

### Foundation

| # | Decision | Status |
|---|----------|--------|
| [DD-01](#dd-01-package-structure--module-namespacing) | Package Structure & Module Namespacing | 🔲 |
| [DD-02](#dd-02-behaviours-protocols-and-structs-convention) | Behaviours, Protocols, and Structs Convention | 🔲 |
| [DD-03](#dd-03-error-handling-strategy) | Error Handling Strategy | 🔲 |
| [DD-04](#dd-04-configuration--environment-variable-system) | Configuration & Environment Variable System | 🔲 |

### Common

| # | Decision | Status |
|---|----------|--------|
| [DD-05](#dd-05-anyvalue-type-system) | AnyValue Type System | 🔲 |
| [DD-06](#dd-06-attribute--attribute-collections) | Attribute & Attribute Collections | 🔲 |
| [DD-07](#dd-07-attribute-limits) | Attribute Limits | 🔲 |

### Context

| # | Decision | Status |
|---|----------|--------|
| [DD-08](#dd-08-context-data-structure--operations) | Context Data Structure & Operations | 🔲 |
| [DD-09](#dd-09-context-attachdetach--process-local-storage) | Context Attach/Detach & Process-Local Storage | 🔲 |
| [DD-10](#dd-10-cross-process-context-passing) | Cross-Process Context Passing | 🔲 |

### Resource

| # | Decision | Status |
|---|----------|--------|
| [DD-11](#dd-11-resource-creation--merge) | Resource Creation & Merge | 🔲 |
| [DD-12](#dd-12-resource-detection--environment-variables) | Resource Detection & Environment Variables | 🔲 |

### Trace API — Provider & Tracer

| # | Decision | Status |
|---|----------|--------|
| [DD-13](#dd-13-tracerprovider-api) | TracerProvider API | 🔲 |
| [DD-14](#dd-14-tracer--instrumentationscope) | Tracer & InstrumentationScope | 🔲 |

### Trace API — SpanContext

| # | Decision | Status |
|---|----------|--------|
| [DD-15](#dd-15-spancontext-struct) | SpanContext Struct | 🔲 |
| [DD-16](#dd-16-spancontext-validation--remote) | SpanContext Validation & Remote | 🔲 |
| [DD-17](#dd-17-tracestate) | TraceState | 🔲 |

### Trace API — Span

| # | Decision | Status |
|---|----------|--------|
| [DD-18](#dd-18-span-interface--lifecycle) | Span Interface & Lifecycle | 🔲 |
| [DD-19](#dd-19-span-creation) | Span Creation | 🔲 |
| [DD-20](#dd-20-span-operations-attributes--events) | Span Operations: Attributes & Events | 🔲 |
| [DD-21](#dd-21-span-operations-links-status-end) | Span Operations: Links, Status, End | 🔲 |
| [DD-22](#dd-22-span-operations-recordexception) | Span Operations: RecordException | 🔲 |
| [DD-23](#dd-23-nonrecordingspan--no-sdk-behavior) | NonRecordingSpan & No-SDK Behavior | 🔲 |
| [DD-24](#dd-24-trace-context-interaction) | Trace Context Interaction | 🔲 |

### Trace SDK — Provider & Configuration

| # | Decision | Status |
|---|----------|--------|
| [DD-25](#dd-25-tracerprovider-sdk-configuration) | TracerProvider SDK: Configuration | 🔲 |
| [DD-26](#dd-26-tracerprovider-sdk-shutdown--forceflush) | TracerProvider SDK: Shutdown & ForceFlush | 🔲 |

### Trace SDK — Sampling

| # | Decision | Status |
|---|----------|--------|
| [DD-27](#dd-27-sampler-interface--shouldsample) | Sampler Interface & ShouldSample | 🔲 |
| [DD-28](#dd-28-built-in-samplers) | Built-in Samplers | 🔲 |

### Trace SDK — Span Creation & Storage

| # | Decision | Status |
|---|----------|--------|
| [DD-29](#dd-29-id-generation) | ID Generation | 🔲 |
| [DD-30](#dd-30-sdk-span-creation-flow) | SDK Span Creation Flow | 🔲 |
| [DD-31](#dd-31-span-storage--ets-design) | Span Storage & ETS Design | 🔲 |

### Trace SDK — Span Processors

| # | Decision | Status |
|---|----------|--------|
| [DD-32](#dd-32-spanprocessor-interface) | SpanProcessor Interface | 🔲 |
| [DD-33](#dd-33-simplespanprocessor) | SimpleSpanProcessor | 🔲 |
| [DD-34](#dd-34-batchspanprocessor) | BatchSpanProcessor | 🔲 |

### Trace SDK — Span Exporters

| # | Decision | Status |
|---|----------|--------|
| [DD-35](#dd-35-spanexporter-interface) | SpanExporter Interface | 🔲 |
| [DD-36](#dd-36-console-stdout-exporter) | Console (stdout) Exporter | 🔲 |

### Propagators

| # | Decision | Status |
|---|----------|--------|
| [DD-37](#dd-37-textmappropagator-interface) | TextMapPropagator Interface | 🔲 |
| [DD-38](#dd-38-composite-propagator--global-registration) | Composite Propagator & Global Registration | 🔲 |
| [DD-39](#dd-39-w3c-tracecontext-propagator) | W3C TraceContext Propagator | 🔲 |

### Baggage

| # | Decision | Status |
|---|----------|--------|
| [DD-40](#dd-40-baggage-api) | Baggage API | 🔲 |
| [DD-41](#dd-41-w3c-baggage-propagator) | W3C Baggage Propagator | 🔲 |

### OTP Infrastructure

| # | Decision | Status |
|---|----------|--------|
| [DD-42](#dd-42-supervision-tree-structure) | Supervision Tree Structure | 🔲 |
| [DD-43](#dd-43-application-boot-order) | Application Boot Order | 🔲 |

## Phase 2: OTLP HTTP Exporter

| # | Decision | Status |
|---|----------|--------|
| [DD-44](#dd-44-otlp-http-exporter) | OTLP HTTP Exporter | 🔲 |
| [DD-50](#dd-50-exporter-packaging-strategy) | Exporter Packaging Strategy | 🔲 |

## Phase 3: Metrics

| # | Decision | Status |
|---|----------|--------|
| [DD-45](#dd-45-metrics-api) | Metrics API | 🔲 |
| [DD-46](#dd-46-metrics-sdk) | Metrics SDK | 🔲 |

## Phase 4: Logs, Baggage, OTLP gRPC

| # | Decision | Status |
|---|----------|--------|
| [DD-47](#dd-47-logs-api--sdk) | Logs API & SDK | 🔲 |
| [DD-48](#dd-48-logger-integration) | :logger Integration | 🔲 |
| [DD-49](#dd-49-otlp-grpc-exporter) | OTLP gRPC Exporter | 🔲 |

---

## DD-01. Package Structure & Module Namespacing

Hex 패키지 구성(단일 vs api/sdk 분리), 모듈 네임스페이스 규칙.

Related compliance:
- [Trace SDK](compliance/trace-sdk.md) — TracerProvider를 통한 Tracer 생성
- [Metrics SDK](compliance/metrics-sdk.md) — SDK 제공 필수
- [Logs SDK](compliance/logs-sdk.md) — SDK 제공 필수

## DD-02. Behaviours, Protocols, and Structs Convention

OTel 확장 포인트(Sampler, SpanProcessor, SpanExporter, TextMapPropagator, IdGenerator)를 Behaviour/Protocol/Struct 중 어떤 것으로 표현할지.

Related compliance:
- [Resource](compliance/resource.md) — Resource 생성 및 텔레메트리 연관
- [Trace API](compliance/trace-api.md) — Span 생성은 Tracer를 통해서만
- [Trace SDK](compliance/trace-sdk.md) — SpanProcessor/SpanExporter/Sampler 인터페이스

## DD-03. Error Handling Strategy

OTel의 "must not throw" 규칙과 BEAM "let it crash" 사이의 경계.

Related compliance:
- [Trace API](compliance/trace-api.md) — 유효하지 않은 이름에 fallback 반환, blocking I/O 금지
- [Trace SDK](compliance/trace-sdk.md) — shutdown 후 no-op 반환
- [Metrics SDK](compliance/metrics-sdk.md) — shutdown 후 no-op 반환
- [Logs SDK](compliance/logs-sdk.md) — shutdown 후 no-op 반환
- [API Propagators](compliance/api-propagators.md) — Extract에서 예외 금지

## DD-04. Configuration & Environment Variable System

`OTEL_*` 환경변수 로딩/파싱/우선순위, Application config 통합.

Related compliance:
- [Environment Variables](compliance/environment-variables.md) — 전체 (29항목)
- [Trace SDK](compliance/trace-sdk.md) — TracerProvider 설정 소유, 업데이트 전파
- [Common](compliance/common.md) — 속성 제한 프로그래밍 방식 변경
- [OTLP Exporter](compliance/otlp-exporter.md) — 설정 옵션, signal별 오버라이드
- [Resource](compliance/resource.md) — OTEL_RESOURCE_ATTRIBUTES
- [API Propagators](compliance/api-propagators.md) — propagator 설정 오버라이드

## DD-05. AnyValue Type System

AnyValue 타입 표현, homogeneous array, null 처리, 비OTLP 프로토콜용 인코딩.

Related compliance:
- [Common](compliance/common.md) — AnyValue (5항목), AnyValue Representation for Non-OTLP (19항목)

## DD-06. Attribute & Attribute Collections

Attribute key-value 구조, 유일 키 보장, 덮어쓰기 규칙.

Related compliance:
- [Common](compliance/common.md) — Attribute (3항목), Attribute Collections (3항목)

## DD-07. Attribute Limits

속성 개수/길이 제한, truncation, discard, dropped count 추적, 검증 시점.

Related compliance:
- [Common](compliance/common.md) — Attribute Limits (13항목)
- [Trace SDK](compliance/trace-sdk.md) — Span Limits (6항목)

## DD-08. Context Data Structure & Operations

Context 불변 구조체, Key 생성(opaque), Get/Set Value.

Related compliance:
- [Context](compliance/context.md) — Overview (1항목), Create a Key (3항목), Get Value (2항목), Set Value (2항목)

## DD-09. Context Attach/Detach & Process-Local Storage

프로세스 내 현재 Context 저장(pdict vs ETS), token 기반 attach/detach.

Related compliance:
- [Context](compliance/context.md) — Optional Global Operations (5항목)

## DD-10. Cross-Process Context Passing

Task.async, GenServer.call, 메시지 패싱에서 Context 전파 전략.

Related compliance:
- BEAM 특화 결정. OTel spec에 직접 대응하는 compliance 항목 없음.

## DD-11. Resource Creation & Merge

Resource 구조체, 생성, 병합 규칙, SDK 기본 Resource.

Related compliance:
- [Resource](compliance/resource.md) — Resource SDK (2항목), SDK-provided (2항목), Create (1항목), Merge (3항목)

## DD-12. Resource Detection & Environment Variables

커스텀 detector, OTEL_RESOURCE_ATTRIBUTES 파싱, Schema URL 처리.

Related compliance:
- [Resource](compliance/resource.md) — Detecting (6항목), Environment Variable Resource (4항목)

## DD-13. TracerProvider API

글로벌 등록, 다수 인스턴스 허용, Get a Tracer 함수.

Related compliance:
- [Trace API](compliance/trace-api.md) — TracerProvider (3항목)

## DD-14. Tracer & InstrumentationScope

Tracer 생성 파라미터(name, version, schema_url), 유효하지 않은 이름 처리, 설정 변경 반영.

Related compliance:
- [Trace API](compliance/trace-api.md) — Get a Tracer (6항목)
- [Trace SDK](compliance/trace-sdk.md) — Tracer Creation (3항목)

## DD-15. SpanContext Struct

SpanContext 생성, TraceId/SpanId Hex/Binary 표현, 내부 저장 방식.

Related compliance:
- [Trace API](compliance/trace-api.md) — SpanContext (3항목), Retrieving TraceId/SpanId (6항목)

## DD-16. SpanContext Validation & Remote

IsValid(non-zero ID), IsRemote(원격 전파 여부).

Related compliance:
- [Trace API](compliance/trace-api.md) — IsValid (1항목), IsRemote (3항목)

## DD-17. TraceState

TraceState 불변 연산(get/add/update/delete), W3C 유효성 검증.

Related compliance:
- [Trace API](compliance/trace-api.md) — TraceState (6항목)

## DD-18. Span Interface & Lifecycle

Span 이름 규칙, 시작/종료 시간, 종료 후 불변성, Tracer를 통한 생성만 허용.

Related compliance:
- [Trace API](compliance/trace-api.md) — Span (7항목), Span Lifetime (1항목)

## DD-19. Span Creation

생성 파라미터(name, parent Context, attributes, links, start timestamp), root span, 부모 결정 규칙.

Related compliance:
- [Trace API](compliance/trace-api.md) — Span Creation (15항목), Specifying Links (1항목)

## DD-20. Span Operations: Attributes & Events

SetAttribute(단일/다수, 덮어쓰기), AddEvent(이름, 타임스탬프, 속성).

Related compliance:
- [Trace API](compliance/trace-api.md) — Set Attributes (3항목), Add Events (3항목)

## DD-21. Span Operations: Links, Status, End

AddLink, SetStatus(Unset/Ok/Error, description), End(타임스탬프, 후속 호출 무시, blocking I/O 금지).

Related compliance:
- [Trace API](compliance/trace-api.md) — Add Link (1항목), Set Status (11항목), End (7항목)

## DD-22. Span Operations: RecordException

예외를 Event로 기록, 최소 인자, 추가 속성.

Related compliance:
- [Trace API](compliance/trace-api.md) — Record Exception (5항목)

## DD-23. NonRecordingSpan & No-SDK Behavior

SpanContext 래핑, IsRecording=false, no-op 연산, SDK 미설치 시 동작.

Related compliance:
- [Trace API](compliance/trace-api.md) — Wrapping SpanContext (8항목), No-SDK Behavior (3항목)

## DD-24. Trace Context Interaction

Context에서 Span 추출/결합, active span get/set, Context Key 은닉.

Related compliance:
- [Trace API](compliance/trace-api.md) — Context Interaction (6항목)

## DD-25. TracerProvider SDK: Configuration

SpanProcessors, IdGenerator, SpanLimits, Sampler 설정 소유, 업데이트 전파.

Related compliance:
- [Trace SDK](compliance/trace-sdk.md) — Configuration (3항목)

## DD-26. TracerProvider SDK: Shutdown & ForceFlush

Shutdown 1회만, no-op 반환, timeout, 모든 processor에 전파, ForceFlush.

Related compliance:
- [Trace SDK](compliance/trace-sdk.md) — Shutdown (5항목), ForceFlush (3항목)

## DD-27. Sampler Interface & ShouldSample

ShouldSample 파라미터/반환값, SampledFlag과 IsRecording 규칙, GetDescription.

Related compliance:
- [Trace SDK](compliance/trace-sdk.md) — Sampling (5항목), ShouldSample (4항목), GetDescription (1항목)

## DD-28. Built-in Samplers

AlwaysOn, AlwaysOff, TraceIdRatioBased(결정적 해시, 확률 포함 관계).

Related compliance:
- [Trace SDK](compliance/trace-sdk.md) — AlwaysOn (1항목), AlwaysOff (1항목), TraceIdRatioBased (5항목)

## DD-29. ID Generation

기본 랜덤 생성, 커스텀 IdGenerator, 메서드 이름 일관성.

Related compliance:
- [Trace SDK](compliance/trace-sdk.md) — Id Generators (4항목)

## DD-30. SDK Span Creation Flow

생성 순서(TraceId → Sampler → SpanId → Span), ReadableSpan/ReadWriteSpan 인터페이스.

Related compliance:
- [Trace SDK](compliance/trace-sdk.md) — SDK Span Creation (1항목), Additional Span Interfaces (7항목)

## DD-31. Span Storage & ETS Design

활성 Span 저장소(ETS 테이블 설계), 소유권, 동시 접근, crash 정리.

Related compliance:
- [Trace API](compliance/trace-api.md) — Concurrency Requirements (5항목)
- [Trace SDK](compliance/trace-sdk.md) — Concurrency requirements (4항목)

## DD-32. SpanProcessor Interface

OnStart/OnEnd/OnEnding/Shutdown/ForceFlush 메서드 정의, 생명주기.

Related compliance:
- [Trace SDK](compliance/trace-sdk.md) — Interface Definition (2항목), OnStart (1항목), OnEnd (1항목), Shutdown (5항목), ForceFlush (6항목)

## DD-33. SimpleSpanProcessor

동기식 Export, Export 직렬화.

Related compliance:
- [Trace SDK](compliance/trace-sdk.md) — Simple Processor (1항목), Built-in (1항목)

## DD-34. BatchSpanProcessor

배치 큐(mailbox vs ETS vs :queue), scheduledDelay 타이머, maxExportBatchSize, backpressure.

Related compliance:
- [Trace SDK](compliance/trace-sdk.md) — Batching Processor (2항목)
- [OTLP Protocol](compliance/otlp-protocol.md) — 동시 요청, throttling

## DD-35. SpanExporter Interface

Export/Shutdown/ForceFlush, 동시성 문서화, timeout, 재시도 금지.

Related compliance:
- [Trace SDK](compliance/trace-sdk.md) — Exporter Interface (2항목), Export (2항목), ForceFlush (3항목)

## DD-36. Console (stdout) Exporter

stdout 출력 포맷, SimpleProcessor와 페어링.

Related compliance:
- [Trace Exporters](compliance/trace-exporters.md) — 전체 (2항목)

## DD-37. TextMapPropagator Interface

Inject/Extract, Getter/Setter(stateless), carrier 타입, US-ASCII 제한.

Related compliance:
- [API Propagators](compliance/api-propagators.md) — Operations (5항목), TextMap Propagator (11항목)

## DD-38. Composite Propagator & Global Registration

다수 Propagator 그룹화, 글로벌 get/set, no-op 기본값, W3C 기본 구성.

Related compliance:
- [API Propagators](compliance/api-propagators.md) — Composite (2항목), Global (7항목), Distribution (1항목)

## DD-39. W3C TraceContext Propagator

traceparent/tracestate 파싱/유효성검증/전파.

Related compliance:
- [API Propagators](compliance/api-propagators.md) — W3C Trace Context (3항목)

## DD-40. Baggage API

Baggage 불변 구조체, Get/Set/Remove/Clear, Context 상호작용, SDK 없이 동작.

Related compliance:
- [Baggage](compliance/baggage.md) — 전체 (17항목)

## DD-41. W3C Baggage Propagator

W3C Baggage TextMapPropagator 구현.

Related compliance:
- [Baggage](compliance/baggage.md) — Propagation (1항목)
- [API Propagators](compliance/api-propagators.md) — Distribution (1항목)

## DD-42. Supervision Tree Structure

TracerProvider, SpanProcessor, Exporter의 OTP 감독 트리, restart strategy.

Related compliance:
- [Trace SDK](compliance/trace-sdk.md) — Concurrency requirements (4항목)
- [Trace API](compliance/trace-api.md) — Concurrency Requirements (5항목)

## DD-43. Application Boot Order

Provider readiness 보장, OTP app 의존성, lazy init, timeout.

Related compliance:
- [Trace SDK](compliance/trace-sdk.md) — Shutdown timeout 관련
- [OTLP Protocol](compliance/otlp-protocol.md) — shutdown 대기 옵션

## DD-44. OTLP HTTP Exporter

OTLP HTTP/protobuf 익스포터 구현.

Related compliance:
- [OTLP Protocol](compliance/otlp-protocol.md) — 전체 (75항목)
- [OTLP Exporter](compliance/otlp-exporter.md) — 전체 (17항목)

## DD-45. Metrics API

Meter, Instruments, 동기/비동기 인터페이스.

Related compliance:
- [Metrics API](compliance/metrics-api.md) — 전체 (97항목)

## DD-46. Metrics SDK

MeterProvider, MetricReader, Aggregation, Views.

Related compliance:
- [Metrics SDK](compliance/metrics-sdk.md) — 전체 (192항목)
- [Metrics Exporters](compliance/metrics-exporters.md) — 전체 (5항목)

## DD-47. Logs API & SDK

LoggerProvider, Logger, LogRecord, LogRecordProcessor.

Related compliance:
- [Logs API](compliance/logs-api.md) — 전체 (28항목)
- [Logs SDK](compliance/logs-sdk.md) — 전체 (71항목)
- [Logs Exporters](compliance/logs-exporters.md) — 전체 (2항목)

## DD-48. :logger Integration

OTel Logs 시그널과 Erlang `:logger` 프레임워크 통합.

Related compliance:
- [Logs API](compliance/logs-api.md) — LoggerProvider/Logger 인터페이스
- [Logs SDK](compliance/logs-sdk.md) — LogRecordProcessor 생명주기

## DD-49. OTLP gRPC Exporter

OTLP gRPC/protobuf 익스포터 구현.

Related compliance:
- [OTLP Protocol](compliance/otlp-protocol.md) — gRPC 관련
- [OTLP Exporter](compliance/otlp-exporter.md) — transport 선택

## DD-50. Exporter Packaging Strategy

Console/OTLP HTTP/gRPC 익스포터 패키지 분리 전략.

Related compliance:
- [Trace Exporters](compliance/trace-exporters.md) — exporter 페어링
- [Metrics Exporters](compliance/metrics-exporters.md) — exporter 설정
- [Logs Exporters](compliance/logs-exporters.md) — exporter 페어링
