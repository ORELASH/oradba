# Log Specification — Kafbat

## Project Overview

| Field | Value |
|---|---|
| **Title** | Kafbat |
| **Security Manager** | TBD |
| **PII** | false |
| **Log357** | false |
| **Generated** | 2026-08-18 |

## System Description

Kafka UI for users view and ops for basic users. Provides a web-based interface for users to view Kafka topics, consumer groups, brokers, and perform basic operational actions such as browsing messages and managing offsets.

## Log Type Analysis

| Log Type | Included | Reason |
|---|---|---|
| audit | ✅ | Users perform actions on Kafka resources (view topics, reset offsets, produce messages) — all user-initiated operations must be audited |
| system | ✅ | Service lifecycle events (startup, shutdown, health checks) are standard for any deployed service |
| error | ✅ | Unexpected failures connecting to Kafka brokers, API errors, and unhandled exceptions must be captured |
| access | ✅ | The system exposes an HTTP/web UI — all HTTP requests and authentication decisions must be logged |
| security | ✅ | The system includes user authentication and authorization to control which users can perform which ops on which Kafka resources |
| financial | ❌ | Log357 is false; no financial transactions mentioned |
| pii_access | ❌ | PII is false; no personal data handling |
| data_change | ✅ | Users can perform write/mutate operations on Kafka (produce messages, delete topics, reset offsets) — these are data modification events |
| integration | ✅ | Kafbat integrates with Kafka brokers and potentially Schema Registry / Kafka Connect as external services |
| performance | ❌ | No SLA or latency monitoring requirements mentioned |
| scheduler | ❌ | No scheduled jobs or batch tasks mentioned |

## Log Definitions

---

### Audit Log

**Purpose:** Records every user-initiated action on Kafka resources (topic browse, message produce, offset reset, consumer group management).

**ECS Fields:**

| Field | Type | Required | Description |
|---|---|---|---|
| `@timestamp` | date | ✅ | Timestamp when the action occurred |
| `event.kind` | keyword | ✅ | Always `"event"` |
| `event.category` | keyword | ✅ | Always `"configuration"` or `"database"` depending on action |
| `event.type` | keyword | ✅ | `"access"`, `"change"`, or `"deletion"` |
| `event.outcome` | keyword | ✅ | `"success"` or `"failure"` |
| `event.action` | keyword | ✅ | Specific action: `"topic_browse"`, `"message_produce"`, `"offset_reset"`, `"consumer_group_view"`, `"topic_delete"` |
| `event.dataset` | keyword | ✅ | Always `"kafbat.audit"` |
| `service.name` | keyword | ✅ | Always `"kafbat"` |
| `service.version` | keyword | ❌ | Deployed version of Kafbat |
| `host.hostname` | keyword | ✅ | Hostname of the Kafbat instance |
| `log.level` | keyword | ✅ | `"info"` for success, `"warn"` for failure |
| `message` | text | ✅ | Human-readable description of the action |
| `user.id` | keyword | ✅ | Unique identifier of the acting user |
| `user.name` | keyword | ✅ | Username of the acting user |
| `user.email` | keyword | ❌ | Email of the acting user |
| `user.roles` | keyword | ❌ | Roles assigned to the user (array) |
| `source.ip` | ip | ✅ | Client IP address of the user |
| `user_agent.original` | keyword | ❌ | Browser / client user-agent string |
| `kafbat.resource_type` | keyword | ✅ | Kafka resource type acted upon: `"topic"`, `"consumer_group"`, `"broker"`, `"schema"` |
| `kafbat.resource_name` | keyword | ✅ | Name of the specific Kafka resource (e.g. topic name) |
| `kafbat.cluster_name` | keyword | ✅ | Name of the Kafka cluster targeted |
| `AppInfo.cmdbId` | keyword | ✅ | CMDB identifier for Kafbat |
| `AppInfo.name` | keyword | ✅ | Application name: `"kafbat"` |
| `AppInfo.service.id` | keyword | ✅ | Unique service instance ID |
| `AppInfo.service.name` | keyword | ✅ | Service name: `"kafbat-ui"` |

**Example log record (JSON):**
```json
{
  "@timestamp": "2026-08-18T10:23:45.000Z",
  "event": {
    "kind": "event",
    "category": "database",
    "type": "access",
    "outcome": "success",
    "action": "topic_browse",
    "dataset": "kafbat.audit"
  },
  "service": {
    "name": "kafbat",
    "version": "0.7.2"
  },
  "host": {
    "hostname": "kafbat-ui-prod-01"
  },
  "log": {
    "level": "info"
  },
  "message": "User browsed messages on topic 'orders.created'",
  "user": {
    "id": "u-1042",
    "name": "john.doe",
    "email": "john.doe@example.com",
    "roles": ["viewer"]
  },
  "source": {
    "ip": "10.0.1.55"
  },
  "user_agent": {
    "original": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
  },
  "kafbat": {
    "resource_type": "topic",
    "resource_name": "orders.created",
    "cluster_name": "prod-cluster-01"
  },
  "AppInfo": {
    "cmdbId": "CMDB-00421",
    "name": "kafbat",
    "service": {
      "id": "kafbat-ui-001",
      "name": "kafbat-ui"
    }
  }
}
```

---

### System Log

**Purpose:** Records Kafbat service lifecycle events including startup, shutdown, health checks, and Kafka broker connectivity status.

**ECS Fields:**

| Field | Type | Required | Description |
|---|---|---|---|
| `@timestamp` | date | ✅ | Timestamp of the system event |
| `event.kind` | keyword | ✅ | Always `"event"` |
| `event.category` | keyword | ✅ | Always `"host"` or `"process"` |
| `event.type` | keyword | ✅ | `"start"`, `"end"`, `"info"` |
| `event.outcome` | keyword | ✅ | `"success"` or `"failure"` |
| `event.action` | keyword | ✅ | `"start"`, `"stop"`, `"restart"`, `"health_check"`, `"broker_connect"` |
| `service.name` | keyword | ✅ | Always `"kafbat"` |
| `service.version` | keyword | ✅ | Deployed version of Kafbat |
| `host.hostname` | keyword | ✅ | Hostname of the Kafbat instance |
| `host.ip` | ip | ❌ | IP address of the host |
| `log.level` | keyword | ✅ | `"info"`, `"warn"`, or `"error"` |
| `message` | text | ✅ | Human-readable system event description |
| `process.name` | keyword | ✅ | Process name: `"kafbat"` |
| `process.pid` | long | ✅ | Operating system process ID |
| `kafbat.cluster_name` | keyword | ❌ | Kafka cluster name if event is broker-related |
| `kafbat.broker_count` | long | ❌ | Number of connected brokers at health check |
| `AppInfo.cmdbId` | keyword | ✅ | CMDB identifier for Kafbat |
| `AppInfo.name` | keyword | ✅ | Application name: `"kafbat"` |
| `AppInfo.service.id` | keyword | ✅ | Unique service instance ID |
| `AppInfo.service.name` | keyword | ✅ | Service name: `"kafbat-ui"` |

**Example log record (JSON):**
```json
{
  "@timestamp": "2026-08-18T08:00:01.000Z",
  "event": {
    "kind": "event",
    "category": "process",
    "type": "start",
    "outcome": "success",
    "action": "start"
  },
  "service": {
    "name": "kafbat",
    "version": "0.7.2"
  },
  "host": {
    "hostname": "kafbat-ui-prod-01",
    "ip": "10.0.1.20"
  },
  "log": {
    "level": "info"
  },
  "message": "Kafbat UI service started successfully",
  "process": {
    "name": "kafbat",
    "pid": 1024
  },
  "kafbat": {
    "cluster_name": "prod-cluster-01",
    "broker_count": 3
  },
  "AppInfo": {
    "cmdbId": "CMDB-00421",
    "name": "kafbat",
    "service": {
      "id": "kafbat-ui-001",
      "name": "kafbat-ui"
    }
  }
}
```

---

### Error Log

**Purpose:** Captures exceptions, Kafka broker connectivity failures, API errors, and any unexpected system states encountered by Kafbat.

**ECS Fields:**

| Field | Type | Required | Description |
|---|---|---|---|
| `@timestamp` | date | ✅ | Timestamp when the error occurred |
| `event.kind` | keyword | ✅ | Always `"event"` |
| `event.category` | keyword | ✅ | Always `"process"` |
| `event.type` | keyword | ✅ | Always `"error"` |
| `event.outcome` | keyword | ✅ | Always `"failure"` |
| `event.action` | keyword | ✅ | Action that was being attempted when the error occurred |
| `service.name` | keyword | ✅ | Always `"kafbat"` |
| `service.version` | keyword | ❌ | Deployed version of Kafbat |
| `host.hostname` | keyword | ✅ | Hostname of the Kafbat instance |
| `log.level` | keyword | ✅ | `"error"` or `"warn"` |
| `message` | text | ✅ | Human-readable error summary |
| `error.message` | text | ✅ | Full error message from the exception |
| `error.code` | keyword | ✅ | Application or Kafka error code |
| `error.type` | keyword | ✅ | Exception class or error category (e.g. `"KafkaTimeoutException"`) |
| `error.stack_trace` | keyword | ❌ | Full stack trace (omit in production if too verbose) |
| `process.name` | keyword | ✅ | Process name: `"kafbat"` |
| `process.pid` | long | ❌ | Operating system process ID |
| `kafbat.cluster_name` | keyword | ❌ | Kafka cluster name if error is broker-related |
| `kafbat.resource_type` | keyword | ❌ | Resource type involved in the failing operation |
| `kafbat.resource_name` | keyword | ❌ | Resource name involved in the failing operation |
| `AppInfo.cmdbId` | keyword | ✅ | CMDB identifier for Kafbat |
| `AppInfo.name` | keyword | ✅ | Application name: `"kafbat"` |
| `AppInfo.service.id` | keyword | ✅ | Unique service instance ID |
| `AppInfo.service.name` | keyword | ✅ | Service name: `"kafbat-ui"` |

**Example log record (JSON):**
```json
{
  "@timestamp": "2026-08-18T11:05:33.000Z",
  "event": {
    "kind": "event",
    "category": "process",
    "type": "error",
    "outcome": "failure",
    "action": "topic_browse"
  },
  "service": {
    "name": "kafbat",
    "version": "0.7.2"
  },
  "host": {
    "hostname": "kafbat-ui-prod-01"
  },
  "log": {
    "level": "error"
  },
  "message": "Failed to fetch messages from topic 'orders.created': broker timeout",
  "error": {
    "message": "Connection to broker 10.0.2.10:9092 timed out after 30000ms",
    "code": "BROKER_TIMEOUT",
    "type": "org.apache.kafka.common.errors.TimeoutException",
    "stack_trace": "org.apache.kafka.common.errors.TimeoutException: ...\n\tat ..."
  },
  "process": {
    "name": "kafbat",
    "pid": 1024
  },
  "kafbat": {
    "cluster_name": "prod-cluster-01",
    "resource_type": "topic",
    "resource_name": "orders.created"
  },
  "AppInfo": {
    "cmdbId": "CMDB-00421",
    "name": "kafbat",
    "service": {
      "id": "kafbat-ui-001",
      "name": "kafbat-ui"
    }
  }
}
```

---

### Access Log

**Purpose:** Records all HTTP requests to the Kafbat web UI and REST API, including authentication outcomes and authorization decisions.

**ECS Fields:**

| Field | Type | Required | Description |
|---|---|---|---|
| `@timestamp` | date | ✅ | Timestamp of the HTTP request |
| `event.kind` | keyword | ✅ | Always `"event"` |
| `event.category` | keyword | ✅ | `"web"` or `"authentication"` |
| `event.type` | keyword | ✅ | `"access"` or `"denied"` |
| `event.outcome` | keyword | ✅ | `"success"` or `"failure"` |
| `event.action` | keyword | ✅ | `"http_request"`, `"login"`, `"logout"`, `"access_denied"` |
| `service.name` | keyword | ✅ | Always `"kafbat"` |
| `service.version` | keyword | ❌ | Deployed version of Kafbat |
| `host.hostname` | keyword | ✅ | Hostname of the Kafbat instance |
| `log.level` | keyword | ✅ | `"info"` for 2xx/3xx, `"warn"` for 4xx, `"error"` for 5xx |
| `message` | text | ✅ | Human-readable request summary |
| `http.request.method` | keyword | ✅ | HTTP verb: `"GET"`, `"POST"`, `"DELETE"`, etc. |
| `http.response.status_code` | long | ✅ | HTTP response status code |
| `url.path` | keyword | ✅ | Request path (e.g. `/api/clusters/prod/topics`) |
| `url.full` | keyword | ❌ | Full request URL including query string |
| `source.ip` | ip | ✅ | Client IP address |
| `user_agent.original` | keyword | ❌ | Browser / client user-agent string |
| `user.id` | keyword | ❌ | User ID if authenticated (absent for unauthenticated requests) |
| `user.name` | keyword | ❌ | Username if authenticated |
| `AppInfo.cmdbId` | keyword | ✅ | CMDB identifier for Kafbat |
| `AppInfo.name` | keyword | ✅ | Application name: `"kafbat"` |
| `AppInfo.service.id` | keyword | ✅ | Unique service instance ID |
| `AppInfo.service.name` | keyword | ✅ | Service name: `"kafbat-ui"` |

**Example log record (JSON):**
```json
{
  "@timestamp": "2026-08-18T10:23:44.812Z",
  "event": {
    "kind": "event",
    "category": "web",
    "type": "access",
    "outcome": "success",
    "action": "http_request"
  },
  "service": {
    "name": "kafbat",
    "version": "0.7.2"
  },
  "host": {
    "hostname": "kafbat-ui-prod-01"
  },
  "log": {
    "level": "info"
  },
  "message": "GET /api/clusters/prod-cluster-01/topics 200",
  "http": {
    "request": {
      "method": "GET"
    },
    "response": {
      "status_code": 200
    }
  },
  "url": {
    "path": "/api/clusters/prod-cluster-01/topics",
    "full": "https://kafbat.internal/api/clusters/prod-cluster-01/topics"
  },
  "source": {
    "ip": "10.0.1.55"
  },
  "user_agent": {
    "original": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
  },
  "user": {
    "id": "u-1042",
    "name": "john.doe"
  },
  "AppInfo": {
    "cmdbId": "CMDB-00421",
    "name": "kafbat",
    "service": {
      "id": "kafbat-ui-001",
      "name": "kafbat-ui"
    }
  }
}
```

---

### Security Log

**Purpose:** Records authentication events (login, logout, token validation) and authorization decisions (access granted/denied to Kafka resources based on user roles).

**ECS Fields:**

| Field | Type | Required | Description |
|---|---|---|---|
| `@timestamp` | date | ✅ | Timestamp of the security event |
| `event.kind` | keyword | ✅ | Always `"event"` |
| `event.category` | keyword | ✅ | `"authentication"` or `"authorization"` |
| `event.type` | keyword | ✅ | `"start"` (login), `"end"` (logout), `"denied"` (authz failure) |
| `event.outcome` | keyword | ✅ | `"success"` or `"failure"` |
| `event.action` | keyword | ✅ | `"login"`, `"logout"`, `"token_validate"`, `"access_granted"`, `"access_denied"` |
| `service.name` | keyword | ✅ | Always `"kafbat"` |
| `service.version` | keyword | ❌ | Deployed version of Kafbat |
| `host.hostname` | keyword | ✅ | Hostname of the Kafbat instance |
| `log.level` | keyword | ✅ | `"info"` for success, `"warn"` for access denied, `"error"` for attack patterns |
| `message` | text | ✅ | Human-readable security event description |
| `user.id` | keyword | ✅ | User identifier (use anonymous ID if pre-auth) |
| `user.name` | keyword | ✅ | Username (use `"anonymous"` if pre-auth) |
| `source.ip` | ip | ✅ | Client IP address |
| `source.port` | long | ❌ | Client port |
| `destination.ip` | ip | ❌ | Kafbat server IP |
| `destination.port` | long | ❌ | Kafbat server port |
| `network.protocol` | keyword | ❌ | Protocol: `"https"` |
| `kafbat.resource_type` | keyword | ❌ | Resource type the authorization decision was for |
| `kafbat.resource_name` | keyword | ❌ | Resource name the authorization decision was for |
| `kafbat.required_role` | keyword | ❌ | Role required to perform the action |
| `AppInfo.cmdbId` | keyword | ✅ | CMDB identifier for Kafbat |
| `AppInfo.name` | keyword | ✅ | Application name: `"kafbat"` |
| `AppInfo.service.id` | keyword | ✅ | Unique service instance ID |
| `AppInfo.service.name` | keyword | ✅ | Service name: `"kafbat-ui"` |

**Example log record (JSON):**
```json
{
  "@timestamp": "2026-08-18T10:20:01.000Z",
  "event": {
    "kind": "event",
    "category": "authentication",
    "type": "start",
    "outcome": "success",
    "action": "login"
  },
  "service": {
    "name": "kafbat",
    "version": "0.7.2"
  },
  "host": {
    "hostname": "kafbat-ui-prod-01"
  },
  "log": {
    "level": "info"
  },
  "message": "User 'john.doe' authenticated successfully from 10.0.1.55",
  "user": {
    "id": "u-1042",
    "name": "john.doe"
  },
  "source": {
    "ip": "10.0.1.55",
    "port": 51234
  },
  "destination": {
    "ip": "10.0.1.20",
    "port": 443
  },
  "network": {
    "protocol": "https"
  },
  "AppInfo": {
    "cmdbId": "CMDB-00421",
    "name": "kafbat",
    "service": {
      "id": "kafbat-ui-001",
      "name": "kafbat-ui"
    }
  }
}
```

**Example — Authorization Denied:**
```json
{
  "@timestamp": "2026-08-18T10:45:12.000Z",
  "event": {
    "kind": "event",
    "category": "authorization",
    "type": "denied",
    "outcome": "failure",
    "action": "access_denied"
  },
  "service": {
    "name": "kafbat",
    "version": "0.7.2"
  },
  "host": {
    "hostname": "kafbat-ui-prod-01"
  },
  "log": {
    "level": "warn"
  },
  "message": "User 'john.doe' denied access to delete topic 'payments.events' — insufficient role",
  "user": {
    "id": "u-1042",
    "name": "john.doe"
  },
  "source": {
    "ip": "10.0.1.55"
  },
  "kafbat": {
    "resource_type": "topic",
    "resource_name": "payments.events",
    "required_role": "admin"
  },
  "AppInfo": {
    "cmdbId": "CMDB-00421",
    "name": "kafbat",
    "service": {
      "id": "kafbat-ui-001",
      "name": "kafbat-ui"
    }
  }
}
```

---

### Data Change Log

**Purpose:** Records mutating operations on Kafka resources performed via Kafbat, such as producing messages, deleting topics, resetting consumer group offsets, or modifying configurations.

**ECS Fields:**

| Field | Type | Required | Description |
|---|---|---|---|
| `@timestamp` | date | ✅ | Timestamp of the data change |
| `event.kind` | keyword | ✅ | Always `"event"` |
| `event.category` | keyword | ✅ | Always `"database"` |
| `event.type` | keyword | ✅ | `"change"`, `"creation"`, or `"deletion"` |
| `event.outcome` | keyword | ✅ | `"success"` or `"failure"` |
| `event.action` | keyword | ✅ | `"topic_create"`, `"topic_delete"`, `"message_produce"`, `"offset_reset"`, `"config_update"` |
| `service.name` | keyword | ✅ | Always `"kafbat"` |
| `service.version` | keyword | ❌ | Deployed version of Kafbat |
| `host.hostname` | keyword | ✅ | Hostname of the Kafbat instance |
| `log.level` | keyword | ✅ | `"info"` for success, `"error"` for failure |
| `message` | text | ✅ | Human-readable description of the change |
| `user.id` | keyword | ✅ | User who performed the change |
| `user.name` | keyword | ✅ | Username of the actor |
| `kafbat.entity_type` | keyword | ✅ | Kafka entity type: `"topic"`, `"consumer_group"`, `"broker_config"` |
| `kafbat.entity_id` | keyword | ✅ | Name/ID of the Kafka entity modified |
| `kafbat.cluster_name` | keyword | ✅ | Kafka cluster on which the change was made |
| `kafbat.changed_fields` | keyword | ❌ | Array of configuration keys modified (for config changes) |
| `AppInfo.cmdbId` | keyword | ✅ | CMDB identifier for Kafbat |
| `AppInfo.name` | keyword | ✅ | Application name: `"kafbat"` |
| `AppInfo.service.id` | keyword | ✅ | Unique service instance ID |
| `AppInfo.service.name` | keyword | ✅ | Service name: `"kafbat-ui"` |

**Example log record (JSON):**
```json
{
  "@timestamp": "2026-08-18T13:10:05.000Z",
  "event": {
    "kind": "event",
    "category": "database",
    "type": "deletion",
    "outcome": "success",
    "action": "offset_reset"
  },
  "service": {
    "name": "kafbat",
    "version": "0.7.2"
  },
  "host": {
    "hostname": "kafbat-ui-prod-01"
  },
  "log": {
    "level": "info"
  },
  "message": "User 'jane.ops' reset offsets for consumer group 'shipping-service' on topic 'orders.created' to earliest",
  "user": {
    "id": "u-2031",
    "name": "jane.ops"
  },
  "kafbat": {
    "entity_type": "consumer_group",
    "entity_id": "shipping-service",
    "cluster_name": "prod-cluster-01",
    "changed_fields": ["offset"]
  },
  "AppInfo": {
    "cmdbId": "CMDB-00421",
    "name": "kafbat",
    "service": {
      "id": "kafbat-ui-001",
      "name": "kafbat-ui"
    }
  }
}
```

---

### Integration Log

**Purpose:** Records outbound calls from Kafbat to external Kafka brokers, Schema Registry, and Kafka Connect REST APIs, including latency and outcome.

**ECS Fields:**

| Field | Type | Required | Description |
|---|---|---|---|
| `@timestamp` | date | ✅ | Timestamp of the integration call |
| `event.kind` | keyword | ✅ | Always `"event"` |
| `event.category` | keyword | ✅ | Always `"network"` |
| `event.type` | keyword | ✅ | `"connection"` or `"protocol"` |
| `event.outcome` | keyword | ✅ | `"success"` or `"failure"` |
| `event.action` | keyword | ✅ | `"broker_metadata_fetch"`, `"schema_registry_call"`, `"connect_api_call"`, `"admin_api_call"` |
| `event.duration` | long | ✅ | Call duration in nanoseconds |
| `service.name` | keyword | ✅ | Always `"kafbat"` (calling service) |
| `service.version` | keyword | ❌ | Deployed version of Kafbat |
| `host.hostname` | keyword | ✅ | Hostname of the Kafbat instance |
| `log.level` | keyword | ✅ | `"info"` for success, `"warn"` for slow calls, `"error"` for failures |
| `message` | text | ✅ | Human-readable description of the integration call |
| `destination.service.name` | keyword | ✅ | Target service: `"kafka-broker"`, `"schema-registry"`, `"kafka-connect"` |
| `http.request.method` | keyword | ❌ | HTTP verb (for REST-based integrations) |
| `http.response.status_code` | long | ❌ | HTTP status code (for REST-based integrations) |
| `url.full` | keyword | ❌ | Full URL of the integration endpoint |
| `kafbat.cluster_name` | keyword | ✅ | Kafka cluster being communicated with |
| `AppInfo.cmdbId` | keyword | ✅ | CMDB identifier for Kafbat |
| `AppInfo.name` | keyword | ✅ | Application name: `"kafbat"` |
| `AppInfo.service.id` | keyword | ✅ | Unique service instance ID |
| `AppInfo.service.name` | keyword | ✅ | Service name: `"kafbat-ui"` |

**Example log record (JSON):**
```json
{
  "@timestamp": "2026-08-18T10:23:44.500Z",
  "event": {
    "kind": "event",
    "category": "network",
    "type": "connection",
    "outcome": "success",
    "action": "schema_registry_call",
    "duration": 45000000
  },
  "service": {
    "name": "kafbat",
    "version": "0.7.2"
  },
  "host": {
    "hostname": "kafbat-ui-prod-01"
  },
  "log": {
    "level": "info"
  },
  "message": "Schema Registry GET /subjects/orders.created-value/versions/latest responded 200 in 45ms",
  "destination": {
    "service": {
      "name": "schema-registry"
    }
  },
  "http": {
    "request": {
      "method": "GET"
    },
    "response": {
      "status_code": 200
    }
  },
  "url": {
    "full": "http://schema-registry.internal:8081/subjects/orders.created-value/versions/latest"
  },
  "kafbat": {
    "cluster_name": "prod-cluster-01"
  },
  "AppInfo": {
    "cmdbId": "CMDB-00421",
    "name": "kafbat",
    "service": {
      "id": "kafbat-ui-001",
      "name": "kafbat-ui"
    }
  }
}
```

---

## Compliance

No PII or Log357 compliance obligations apply to this project.

## Approval

| Role | Name |
|---|---|
| Security Manager | TBD |
| Document Generated | 2026-08-18 |




2026-08-19 05:35:48.338 [parallel-4] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/clusters' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@5b167194
2026-08-19 05:35:48.342 [parallel-1] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/info' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@5b167194
2026-08-19 05:35:48.347 [parallel-4] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization failed: Access Denied
2026-08-19 05:35:48.347 [parallel-1] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization failed: Access Denied
2026-08-19 05:35:48.350 [reactor-http-epoll-4] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.80.239 - - [19/Aug/2026:05:35:48 +0000] "GET /api/info HTTP/1.1" 302 0 16
2026-08-19 05:35:48.350 [reactor-http-epoll-1] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.80.239 - - [19/Aug/2026:05:35:48 +0000] "GET /api/clusters HTTP/1.1" 302 0 14
2026-08-19 05:35:48.358 [reactor-http-epoll-1] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.80.239 - - [19/Aug/2026:05:35:48 +0000] "GET /login HTTP/1.1" 200 1816 1
2026-08-19 05:35:48.362 [reactor-http-epoll-1] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.80.239 - - [19/Aug/2026:05:35:48 +0000] "GET /login HTTP/1.1" 200 1816 0
2026-08-19 05:38:19.312 [parallel-3] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/info' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@5b167194
2026-08-19 05:38:19.311 [parallel-2] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/clusters' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@5b167194
2026-08-19 05:38:19.312 [parallel-2] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization failed: Access Denied
2026-08-19 05:38:19.312 [parallel-3] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization failed: Access Denied
2026-08-19 05:38:19.314 [reactor-http-epoll-1] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.100.208 - - [19/Aug/2026:05:38:19 +0000] "GET /api/clusters HTTP/1.1" 302 0 5
2026-08-19 05:38:19.314 [reactor-http-epoll-4] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.100.208 - - [19/Aug/2026:05:38:19 +0000] "GET /api/info HTTP/1.1" 302 0 4
2026-08-19 05:38:19.320 [reactor-http-epoll-4] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.100.208 - - [19/Aug/2026:05:38:19 +0000] "GET /login HTTP/1.1" 200 1816 1
2026-08-19 05:38:19.325 [reactor-http-epoll-4] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.100.208 - - [19/Aug/2026:05:38:19 +0000] "GET /login HTTP/1.1" 200 1816 1
2026-08-19 05:38:20.362 [parallel-4] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/clusters' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@5b167194
2026-08-19 05:38:20.363 [parallel-4] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization failed: Access Denied
2026-08-19 05:38:20.364 [reactor-http-epoll-3] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.100.208 - - [19/Aug/2026:05:38:20 +0000] "GET /api/clusters HTTP/1.1" 302 0 3
2026-08-19 05:38:20.370 [reactor-http-epoll-3] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.100.208 - - [19/Aug/2026:05:38:20 +0000] "GET /login HTTP/1.1" 200 1816 1
2026-08-19 05:38:22.391 [parallel-1] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/clusters' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@5b167194
2026-08-19 05:38:22.391 [parallel-1] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization failed: Access Denied
2026-08-19 05:38:22.392 [reactor-http-epoll-3] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.100.208 - - [19/Aug/2026:05:38:22 +0000] "GET /api/clusters HTTP/1.1" 302 0 2
2026-08-19 05:38:22.398 [reactor-http-epoll-3] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.100.208 - - [19/Aug/2026:05:38:22 +0000] "GET /login HTTP/1.1" 200 1816 0
2026-08-19 06:47:36.033 [reactor-http-epoll-4] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.109.47 - - [19/Aug/2026:06:47:36 +0000] "GET /login HTTP/1.1" 200 1816 3
2026-08-19 06:47:36.084 [parallel-4] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/index-ToFdRV4e.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 06:47:36.084 [parallel-4] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 06:47:36.097 [reactor-http-epoll-4] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.109.47 - - [19/Aug/2026:06:47:36 +0000] "GET /assets/index-ToFdRV4e.js HTTP/1.1" 200 344993 15
2026-08-19 06:47:36.104 [parallel-1] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/index-D3Fzj2d9.css' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 06:47:36.105 [parallel-1] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 06:47:36.108 [reactor-http-epoll-4] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.109.47 - - [19/Aug/2026:06:47:36 +0000] "GET /assets/index-D3Fzj2d9.css HTTP/1.1" 200 1617 4
2026-08-19 06:47:36.111 [parallel-2] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/@react-router-D-4KBoK_.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 06:47:36.112 [parallel-2] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 06:47:36.121 [reactor-http-epoll-4] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.109.47 - - [19/Aug/2026:06:47:36 +0000] "GET /assets/@react-router-D-4KBoK_.js HTTP/1.1" 200 166169 10
2026-08-19 06:47:36.612 [parallel-3] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/AuthPage-DYy823dD.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 06:47:36.612 [parallel-3] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 06:47:36.612 [parallel-4] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/AlertIcon-CaXsK92Y.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 06:47:36.612 [parallel-4] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 06:47:36.616 [reactor-http-epoll-3] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.109.47 - - [19/Aug/2026:06:47:36 +0000] "GET /assets/AlertIcon-CaXsK92Y.js HTTP/1.1" 200 684 4
2026-08-19 06:47:36.616 [reactor-http-epoll-4] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.109.47 - - [19/Aug/2026:06:47:36 +0000] "GET /assets/AuthPage-DYy823dD.js HTTP/1.1" 200 23430 5
2026-08-19 06:47:36.620 [parallel-1] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/favicon/favicon.svg' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 06:47:36.621 [parallel-1] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 06:47:36.626 [reactor-http-epoll-4] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.109.47 - - [19/Aug/2026:06:47:36 +0000] "GET /favicon/favicon.svg HTTP/1.1" 200 712 7
2026-08-19 06:47:36.653 [parallel-2] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/config/authentication' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 06:47:36.654 [parallel-2] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 06:47:36.664 [reactor-http-epoll-4] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.109.47 - - [19/Aug/2026:06:47:36 +0000] "GET /api/config/authentication HTTP/1.1" 200 39 12
2026-08-19 06:47:36.762 [parallel-3] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/fonts/Inter-Medium.ttf' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 06:47:36.762 [parallel-3] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 06:47:36.763 [parallel-4] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/fonts/Inter-Regular.ttf' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 06:47:36.763 [parallel-4] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 06:47:36.773 [reactor-http-epoll-4] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.109.47 - - [19/Aug/2026:06:47:36 +0000] "GET /fonts/Inter-Medium.ttf HTTP/1.1" 200 308392 12
2026-08-19 06:47:36.773 [reactor-http-epoll-3] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.109.47 - - [19/Aug/2026:06:47:36 +0000] "GET /fonts/Inter-Regular.ttf HTTP/1.1" 200 303504 10
2026-08-19 06:47:48.660 [reactor-http-epoll-3] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.109.47 - - [19/Aug/2026:06:47:47 +0000] "POST /login HTTP/1.1" 302 0 1401
2026-08-19 06:47:48.668 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@5b167194
2026-08-19 06:47:48.669 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 06:47:48.674 [reactor-http-epoll-3] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.109.47 - - [19/Aug/2026:06:47:48 +0000] "GET / HTTP/1.1" 200 1816 8
2026-08-19 06:47:48.710 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/info' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@5b167194
2026-08-19 06:47:48.711 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 06:47:48.715 [reactor-http-epoll-3] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.109.47 - - [19/Aug/2026:06:47:48 +0000] "GET /api/info HTTP/1.1" 200 205 6
2026-08-19 06:47:48.747 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/authorization' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 06:47:48.748 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 06:47:48.751 [reactor-http-epoll-3] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.109.47 - - [19/Aug/2026:06:47:48 +0000] "GET /api/authorization HTTP/1.1" 200 71 4
2026-08-19 06:47:48.783 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/info' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@5b167194
2026-08-19 06:47:48.784 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 06:47:48.785 [reactor-http-epoll-3] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.109.47 - - [19/Aug/2026:06:47:48 +0000] "GET /api/info HTTP/1.1" 200 205 2
2026-08-19 06:47:48.846 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/Dashboard-949avtj_.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 06:47:48.847 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 06:47:48.850 [reactor-http-epoll-3] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.109.47 - - [19/Aug/2026:06:47:48 +0000] "GET /assets/Dashboard-949avtj_.js HTTP/1.1" 200 3137 4
2026-08-19 06:47:48.851 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/ActionComponent.styled-CtMfGuhc.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 06:47:48.851 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 06:47:48.856 [reactor-http-epoll-4] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.109.47 - - [19/Aug/2026:06:47:48 +0000] "GET /assets/ActionComponent.styled-CtMfGuhc.js HTTP/1.1" 200 119533 6
2026-08-19 06:47:48.869 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/Heading.styled-DGSlQalk.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 06:47:48.870 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 06:47:48.871 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/BytesFormatted-QhqsAXvV.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 06:47:48.872 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 06:47:48.872 [reactor-http-epoll-3] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.109.47 - - [19/Aug/2026:06:47:48 +0000] "GET /assets/Heading.styled-DGSlQalk.js HTTP/1.1" 200 285 3
2026-08-19 06:47:48.876 [reactor-http-epoll-4] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.109.47 - - [19/Aug/2026:06:47:48 +0000] "GET /assets/BytesFormatted-QhqsAXvV.js HTTP/1.1" 200 591 5
2026-08-19 06:47:48.895 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/Switch-DR0XBu1-.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 06:47:48.895 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 06:47:48.898 [reactor-http-epoll-3] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.109.47 - - [19/Aug/2026:06:47:48 +0000] "GET /assets/Switch-DR0XBu1-.js HTTP/1.1" 200 1130 3
2026-08-19 06:47:48.899 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/SizeCell-C-hVT6uc.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 06:47:48.899 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 06:47:48.902 [reactor-http-epoll-2] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/ActionCanButton-BCx801KA.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 06:47:48.902 [reactor-http-epoll-2] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 06:47:48.907 [reactor-http-epoll-2] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.109.47 - - [19/Aug/2026:06:47:48 +0000] "GET /assets/ActionCanButton-BCx801KA.js HTTP/1.1" 200 456 6
2026-08-19 06:47:48.906 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/localStoragePersister-D-viOm25.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 06:47:48.908 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 06:47:48.909 [reactor-http-epoll-4] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.109.47 - - [19/Aug/2026:06:47:48 +0000] "GET /assets/SizeCell-C-hVT6uc.js HTTP/1.1" 200 176 11
2026-08-19 06:47:48.910 [reactor-http-epoll-3] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.109.47 - - [19/Aug/2026:06:47:48 +0000] "GET /assets/localStoragePersister-D-viOm25.js HTTP/1.1" 200 590 5
2026-08-19 06:47:48.971 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/clusters' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@5b167194
2026-08-19 06:47:48.975 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 06:47:48.981 [reactor-http-epoll-3] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.109.47 - - [19/Aug/2026:06:47:48 +0000] "GET /api/clusters HTTP/1.1" 200 2 11
2026-08-19 06:48:14.479 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/info' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@5b167194
2026-08-19 06:48:14.479 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 06:48:14.480 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/clusters' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@5b167194
2026-08-19 06:48:14.480 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 06:48:14.481 [reactor-http-epoll-3] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.109.47 - - [19/Aug/2026:06:48:14 +0000] "GET /api/info HTTP/1.1" 200 205 3
2026-08-19 06:48:14.483 [reactor-http-epoll-4] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.109.47 - - [19/Aug/2026:06:48:14 +0000] "GET /api/clusters HTTP/1.1" 200 2 4
2026-08-19 06:48:44.243 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/info' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@5b167194
2026-08-19 06:48:44.243 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/clusters' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@5b167194
2026-08-19 06:48:44.243 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 06:48:44.244 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 06:48:44.246 [reactor-http-epoll-4] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.109.47 - - [19/Aug/2026:06:48:44 +0000] "GET /api/info HTTP/1.1" 200 205 5
2026-08-19 06:48:44.247 [reactor-http-epoll-3] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.109.47 - - [19/Aug/2026:06:48:44 +0000] "GET /api/clusters HTTP/1.1" 200 2 6
2026-08-19 07:03:52.345 [reactor-http-epoll-3] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.101.177 - - [19/Aug/2026:07:03:52 +0000] "GET /login HTTP/1.1" 200 1816 3
2026-08-19 07:03:52.736 [parallel-1] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/index-ToFdRV4e.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 07:03:52.737 [parallel-1] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:03:52.748 [parallel-2] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/index-D3Fzj2d9.css' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 07:03:52.748 [parallel-2] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:03:52.751 [reactor-http-epoll-4] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.101.177 - - [19/Aug/2026:07:03:52 +0000] "GET /assets/index-D3Fzj2d9.css HTTP/1.1" 200 1617 5
2026-08-19 07:03:52.753 [parallel-3] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/@react-router-D-4KBoK_.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 07:03:52.753 [parallel-3] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:03:52.757 [reactor-http-epoll-3] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.101.177 - - [19/Aug/2026:07:03:52 +0000] "GET /assets/index-ToFdRV4e.js HTTP/1.1" 200 344993 22
2026-08-19 07:03:52.759 [reactor-http-epoll-1] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.101.177 - - [19/Aug/2026:07:03:52 +0000] "GET /assets/@react-router-D-4KBoK_.js HTTP/1.1" 200 166169 7
2026-08-19 07:03:53.043 [parallel-4] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/AuthPage-DYy823dD.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 07:03:53.044 [parallel-4] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:03:53.047 [reactor-http-epoll-1] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.101.177 - - [19/Aug/2026:07:03:53 +0000] "GET /assets/AuthPage-DYy823dD.js HTTP/1.1" 200 23430 5
2026-08-19 07:03:53.048 [parallel-1] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/AlertIcon-CaXsK92Y.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 07:03:53.048 [parallel-1] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:03:53.050 [reactor-http-epoll-3] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.101.177 - - [19/Aug/2026:07:03:53 +0000] "GET /assets/AlertIcon-CaXsK92Y.js HTTP/1.1" 200 684 2
2026-08-19 07:03:53.100 [parallel-2] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/favicon/favicon.svg' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 07:03:53.100 [parallel-2] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:03:53.102 [reactor-http-epoll-3] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.101.177 - - [19/Aug/2026:07:03:53 +0000] "GET /favicon/favicon.svg HTTP/1.1" 200 712 3
2026-08-19 07:03:53.106 [parallel-3] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/manifest.json' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 07:03:53.107 [parallel-3] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:03:53.108 [reactor-http-epoll-2] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.101.177 - - [19/Aug/2026:07:03:53 +0000] "GET /manifest.json HTTP/1.1" 200 249 2
2026-08-19 07:03:53.193 [parallel-4] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/config/authentication' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 07:03:53.193 [parallel-4] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:03:53.195 [reactor-http-epoll-3] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.101.177 - - [19/Aug/2026:07:03:53 +0000] "GET /api/config/authentication HTTP/1.1" 200 39 3
2026-08-19 07:03:53.269 [parallel-1] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/fonts/Inter-Medium.ttf' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 07:03:53.269 [parallel-1] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:03:53.270 [parallel-2] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/fonts/Inter-Regular.ttf' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 07:03:53.270 [parallel-2] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:03:53.279 [reactor-http-epoll-3] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.101.177 - - [19/Aug/2026:07:03:53 +0000] "GET /fonts/Inter-Medium.ttf HTTP/1.1" 200 308392 11
2026-08-19 07:03:53.279 [reactor-http-epoll-1] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.101.177 - - [19/Aug/2026:07:03:53 +0000] "GET /fonts/Inter-Regular.ttf HTTP/1.1" 200 303504 10
2026-08-19 07:04:04.437 [reactor-http-epoll-3] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.101.177 - - [19/Aug/2026:07:04:03 +0000] "POST /login HTTP/1.1" 302 0 1028
2026-08-19 07:04:04.445 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@5b167194
2026-08-19 07:04:04.446 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:04:04.448 [reactor-http-epoll-3] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.101.177 - - [19/Aug/2026:07:04:04 +0000] "GET / HTTP/1.1" 200 1816 4
2026-08-19 07:04:04.480 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/info' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@5b167194
2026-08-19 07:04:04.481 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:04:04.482 [reactor-http-epoll-3] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.101.177 - - [19/Aug/2026:07:04:04 +0000] "GET /api/info HTTP/1.1" 200 205 2
2026-08-19 07:04:04.493 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/authorization' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 07:04:04.493 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:04:04.494 [reactor-http-epoll-3] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.101.177 - - [19/Aug/2026:07:04:04 +0000] "GET /api/authorization HTTP/1.1" 200 286 2
2026-08-19 07:04:04.544 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/info' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@5b167194
2026-08-19 07:04:04.544 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:04:04.546 [reactor-http-epoll-3] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.101.177 - - [19/Aug/2026:07:04:04 +0000] "GET /api/info HTTP/1.1" 200 205 3
2026-08-19 07:04:04.604 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/Dashboard-949avtj_.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 07:04:04.604 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:04:04.607 [reactor-http-epoll-3] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.101.177 - - [19/Aug/2026:07:04:04 +0000] "GET /assets/Dashboard-949avtj_.js HTTP/1.1" 200 3137 4
2026-08-19 07:04:04.637 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/ActionComponent.styled-CtMfGuhc.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 07:04:04.637 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:04:04.639 [reactor-http-epoll-1] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/Heading.styled-DGSlQalk.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 07:04:04.639 [reactor-http-epoll-1] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:04:04.639 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/Switch-DR0XBu1-.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 07:04:04.639 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:04:04.641 [reactor-http-epoll-1] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.101.177 - - [19/Aug/2026:07:04:04 +0000] "GET /assets/Heading.styled-DGSlQalk.js HTTP/1.1" 200 285 3
2026-08-19 07:04:04.642 [reactor-http-epoll-4] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.101.177 - - [19/Aug/2026:07:04:04 +0000] "GET /assets/Switch-DR0XBu1-.js HTTP/1.1" 200 1130 3
2026-08-19 07:04:04.642 [reactor-http-epoll-3] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.101.177 - - [19/Aug/2026:07:04:04 +0000] "GET /assets/ActionComponent.styled-CtMfGuhc.js HTTP/1.1" 200 119533 6
2026-08-19 07:04:04.652 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/SizeCell-C-hVT6uc.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 07:04:04.652 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:04:04.653 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/BytesFormatted-QhqsAXvV.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 07:04:04.653 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:04:04.654 [reactor-http-epoll-1] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/ActionCanButton-BCx801KA.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 07:04:04.654 [reactor-http-epoll-1] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:04:04.655 [reactor-http-epoll-3] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.101.177 - - [19/Aug/2026:07:04:04 +0000] "GET /assets/SizeCell-C-hVT6uc.js HTTP/1.1" 200 176 3
2026-08-19 07:04:04.655 [reactor-http-epoll-4] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.101.177 - - [19/Aug/2026:07:04:04 +0000] "GET /assets/BytesFormatted-QhqsAXvV.js HTTP/1.1" 200 591 3
2026-08-19 07:04:04.655 [reactor-http-epoll-1] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.101.177 - - [19/Aug/2026:07:04:04 +0000] "GET /assets/ActionCanButton-BCx801KA.js HTTP/1.1" 200 456 2
2026-08-19 07:04:04.658 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/localStoragePersister-D-viOm25.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 07:04:04.658 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:04:04.660 [reactor-http-epoll-4] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.101.177 - - [19/Aug/2026:07:04:04 +0000] "GET /assets/localStoragePersister-D-viOm25.js HTTP/1.1" 200 590 3
2026-08-19 07:04:04.741 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/clusters' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@5b167194
2026-08-19 07:04:04.741 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:04:04.746 [reactor-http-epoll-4] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.101.177 - - [19/Aug/2026:07:04:04 +0000] "GET /api/clusters HTTP/1.1" 200 347 6
2026-08-19 07:04:06.577 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/ClusterPage-gx6pMY3q.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 07:04:06.577 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:04:06.580 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/index.esm-BgXUD10i.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 07:04:06.580 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:04:06.581 [reactor-http-epoll-4] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.101.177 - - [19/Aug/2026:07:04:06 +0000] "GET /assets/ClusterPage-gx6pMY3q.js HTTP/1.1" 200 32435 5
2026-08-19 07:04:06.583 [reactor-http-epoll-3] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.101.177 - - [19/Aug/2026:07:04:06 +0000] "GET /assets/index.esm-BgXUD10i.js HTTP/1.1" 200 45613 4
2026-08-19 07:04:06.593 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/ace-Bj5lQZzX.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 07:04:06.593 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:04:06.594 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/ErrorPage-D3l2PA1n.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 07:04:06.594 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:04:06.609 [reactor-http-epoll-3] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.101.177 - - [19/Aug/2026:07:04:06 +0000] "GET /assets/ace-Bj5lQZzX.js HTTP/1.1" 200 578640 16
2026-08-19 07:04:06.657 [reactor-http-epoll-4] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.101.177 - - [19/Aug/2026:07:04:06 +0000] "GET /assets/ErrorPage-D3l2PA1n.js HTTP/1.1" 200 1352648 63
2026-08-19 07:04:06.715 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/Search-D1de03s6.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 07:04:06.715 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/ConsumerGroups-i2MEk9wH.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 07:04:06.715 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:04:06.715 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:04:06.717 [reactor-http-epoll-1] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/consumers-Cs9Fl0rn.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 07:04:06.717 [reactor-http-epoll-1] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:04:06.719 [reactor-http-epoll-1] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/ExportIcon-hB54pjUy.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 07:04:06.719 [reactor-http-epoll-1] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:04:06.721 [reactor-http-epoll-1] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.101.177 - - [19/Aug/2026:07:04:06 +0000] "GET /assets/ExportIcon-hB54pjUy.js HTTP/1.1" 200 898 3
2026-08-19 07:04:06.721 [reactor-http-epoll-1] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.101.177 - - [19/Aug/2026:07:04:06 +0000] "GET /assets/consumers-Cs9Fl0rn.js HTTP/1.1" 200 1947 5
2026-08-19 07:04:06.722 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/exportTableCSV-DP-FmEJv.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 07:04:06.722 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:04:06.723 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/ControlPanel.styled-CWc6yswd.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 07:04:06.724 [reactor-http-epoll-3] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.101.177 - - [19/Aug/2026:07:04:06 +0000] "GET /assets/Search-D1de03s6.js HTTP/1.1" 200 4374 10
2026-08-19 07:04:06.724 [reactor-http-epoll-3] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.101.177 - - [19/Aug/2026:07:04:06 +0000] "GET /assets/exportTableCSV-DP-FmEJv.js HTTP/1.1" 200 1994 2
2026-08-19 07:04:06.723 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:04:06.726 [reactor-http-epoll-1] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/index-Cj7wsYkN.css' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 07:04:06.726 [reactor-http-epoll-1] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:04:06.726 [reactor-http-epoll-4] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.101.177 - - [19/Aug/2026:07:04:06 +0000] "GET /assets/ControlPanel.styled-CWc6yswd.js HTTP/1.1" 200 3505 3
2026-08-19 07:04:06.727 [reactor-http-epoll-1] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/index-N_7uqvWG.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 07:04:06.727 [reactor-http-epoll-1] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:04:06.728 [reactor-http-epoll-4] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.101.177 - - [19/Aug/2026:07:04:06 +0000] "GET /assets/ConsumerGroups-i2MEk9wH.js HTTP/1.1" 200 15353 15
2026-08-19 07:04:06.729 [reactor-http-epoll-1] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.101.177 - - [19/Aug/2026:07:04:06 +0000] "GET /assets/index-Cj7wsYkN.css HTTP/1.1" 200 21912 4
2026-08-19 07:04:06.732 [reactor-http-epoll-1] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.101.177 - - [19/Aug/2026:07:04:06 +0000] "GET /assets/index-N_7uqvWG.js HTTP/1.1" 200 155211 5
2026-08-19 07:04:06.732 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/Table.styled-Bq0NrV6x.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 07:04:06.732 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:04:06.734 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/constants-BZRZA7RH.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 07:04:06.736 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:04:06.736 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/Form.styled-BOcoibvk.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 07:04:06.736 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:04:06.737 [reactor-http-epoll-1] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/DownloadCsvButton-17ENBEk4.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 07:04:06.737 [reactor-http-epoll-1] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:04:06.738 [reactor-http-epoll-3] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.101.177 - - [19/Aug/2026:07:04:06 +0000] "GET /assets/constants-BZRZA7RH.js HTTP/1.1" 200 595 4
2026-08-19 07:04:06.739 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/ControlledSelect-0wvfMNq1.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 07:04:06.739 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:04:06.739 [reactor-http-epoll-1] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.101.177 - - [19/Aug/2026:07:04:06 +0000] "GET /assets/DownloadCsvButton-17ENBEk4.js HTTP/1.1" 200 700 2
2026-08-19 07:04:06.740 [reactor-http-epoll-3] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.101.177 - - [19/Aug/2026:07:04:06 +0000] "GET /assets/Table.styled-Bq0NrV6x.js HTTP/1.1" 200 2936 8
2026-08-19 07:04:06.740 [reactor-http-epoll-1] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/queryPersister-CkyJ1WEQ.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 07:04:06.740 [reactor-http-epoll-1] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:04:06.742 [reactor-http-epoll-1] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.101.177 - - [19/Aug/2026:07:04:06 +0000] "GET /assets/queryPersister-CkyJ1WEQ.js HTTP/1.1" 200 1159 2
2026-08-19 07:04:06.744 [reactor-http-epoll-4] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.101.177 - - [19/Aug/2026:07:04:06 +0000] "GET /assets/Form.styled-BOcoibvk.js HTTP/1.1" 200 419 10
2026-08-19 07:04:06.744 [reactor-http-epoll-4] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.101.177 - - [19/Aug/2026:07:04:06 +0000] "GET /assets/ControlledSelect-0wvfMNq1.js HTTP/1.1" 200 522 6
2026-08-19 07:04:06.797 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/clusters/kafka-dev/consumer-groups/paged' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@5b167194
2026-08-19 07:04:06.797 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:04:06.855 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/clusters' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@5b167194
2026-08-19 07:04:06.855 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:04:06.859 [reactor-http-epoll-4] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.101.177 - - [19/Aug/2026:07:04:06 +0000] "GET /api/clusters HTTP/1.1" 200 347 5
2026-08-19 07:04:07.031 [reactor-http-epoll-4] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.101.177 - - [19/Aug/2026:07:04:06 +0000] "GET /api/clusters/kafka-dev/consumer-groups/paged?page=1&perPage=25&search=&fts=false HTTP/1.1" 200 10261 237
2026-08-19 07:04:07.067 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/clusters/kafka-dev/consumer-groups/lag' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@5b167194
2026-08-19 07:04:07.067 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:04:07.111 [reactor-http-epoll-4] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.101.177 - - [19/Aug/2026:07:04:07 +0000] "GET /api/clusters/kafka-dev/consumer-groups/lag?ids=00000000-0000-0000-0000-000000000000%2C1ad110bf-8495-45c3-ad86-f381aba5d498%2C233a2246-4058-4372-9152-64da5300d8d4%2C8a6d34d8-ba47-4f14-94f8-4a11edbb5090%2C9709eab5-a62c-4e14-86c8-788b0093aeb2%2C9de4d6a0-517b-4430-8f6b-41d5ad66d7b6%2CAutostradaConsumer%2CAutostradaConsumerTst%2CCRM_EVENTS_MANAGER_DEV%2CCRM_EVENTS_MANAGER_QA%2CConfluentTelemetryReporterSampler--1376390082729492237%2CConfluentTelemetryReporterSampler--1514169218269441824%2CConfluentTelemetryReporterSampler--1825185569671062292%2CConfluentTelemetryReporterSampler--1940318048761466766%2CConfluentTelemetryReporterSampler--2323082807454977515%2CConfluentTelemetryReporterSampler--2600373244947787954%2CConfluentTelemetryReporterSampler--3141836770791098188%2CConfluentTelemetryReporterSampler--3273925817795670735%2CConfluentTelemetryReporterSampler--3976257489741481908%2CConfluentTelemetryReporterSampler--4349492312950127819%2CConfluentTelemetryReporterSampler--8899467541848480339%2CConfluentTelemetryReporterSampler--960951064319115256%2CConfluentTelemetryReporterSampler-1781726918189364072%2CConfluentTelemetryReporterSampler-2505996583812895036%2CConfluentTelemetryReporterSampler-2615068261816032270&includePartitions=false HTTP/1.1" 200 4454 45
2026-08-19 07:04:09.188 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/Topics-omnPFAqB.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 07:04:09.188 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:04:09.191 [reactor-http-epoll-4] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.101.177 - - [19/Aug/2026:07:04:09 +0000] "GET /assets/Topics-omnPFAqB.js HTTP/1.1" 200 3408 4
2026-08-19 07:04:09.208 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/ListPage-DlYXLXno.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 07:04:09.209 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:04:09.209 [reactor-http-epoll-1] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/PlusIcon-ZsK0o-cX.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 07:04:09.209 [reactor-http-epoll-1] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:04:09.211 [reactor-http-epoll-1] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.101.177 - - [19/Aug/2026:07:04:09 +0000] "GET /assets/PlusIcon-ZsK0o-cX.js HTTP/1.1" 200 434 3
2026-08-19 07:04:09.211 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/ActionButton-COAQ-YGZ.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 07:04:09.211 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:04:09.213 [reactor-http-epoll-4] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.101.177 - - [19/Aug/2026:07:04:09 +0000] "GET /assets/ListPage-DlYXLXno.js HTTP/1.1" 200 7065 5
2026-08-19 07:04:09.213 [reactor-http-epoll-4] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.101.177 - - [19/Aug/2026:07:04:09 +0000] "GET /assets/ActionButton-COAQ-YGZ.js HTTP/1.1" 200 665 3
2026-08-19 07:04:09.273 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/clusters/kafka-dev/topics' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@5b167194
2026-08-19 07:04:09.274 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:04:09.667 [reactor-http-epoll-4] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.101.177 - - [19/Aug/2026:07:04:09 +0000] "GET /api/clusters/kafka-dev/topics?page=1&perPage=25&showInternal=true&fts=false HTTP/1.1" 200 12312 394
2026-08-19 07:04:19.431 [reactor-http-epoll-1] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/info' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@5b167194
2026-08-19 07:04:19.432 [reactor-http-epoll-1] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:04:19.431 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/clusters' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@5b167194
2026-08-19 07:04:19.433 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:04:19.435 [reactor-http-epoll-1] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.109.47 - - [19/Aug/2026:07:04:19 +0000] "GET /api/info HTTP/1.1" 200 205 6
2026-08-19 07:04:19.436 [reactor-http-epoll-4] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.109.47 - - [19/Aug/2026:07:04:19 +0000] "GET /api/clusters HTTP/1.1" 200 2 7
2026-08-19 07:04:30.368 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/clusters/kafka-dev/topics' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@5b167194
2026-08-19 07:04:30.368 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:04:30.675 [reactor-http-epoll-4] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.101.177 - - [19/Aug/2026:07:04:30 +0000] "GET /api/clusters/kafka-dev/topics?page=1&perPage=25&showInternal=true&search=b&fts=false HTTP/1.1" 200 12312 308
2026-08-19 07:04:33.266 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/clusters/kafka-dev/topics' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@5b167194
2026-08-19 07:04:33.267 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:04:33.562 [reactor-http-epoll-4] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.101.177 - - [19/Aug/2026:07:04:33 +0000] "GET /api/clusters/kafka-dev/topics?page=1&perPage=25&showInternal=true&search=bll.ems.me&fts=false HTTP/1.1" 200 12312 297
2026-08-19 07:04:33.979 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/clusters/kafka-dev/topics' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@5b167194
2026-08-19 07:04:33.979 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:04:34.284 [reactor-http-epoll-4] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.101.177 - - [19/Aug/2026:07:04:33 +0000] "GET /api/clusters/kafka-dev/topics?page=1&perPage=25&showInternal=true&search=bll.ems.mes&fts=false HTTP/1.1" 200 12312 306
2026-08-19 07:04:37.176 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/clusters/kafka-dev/topics' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@5b167194
2026-08-19 07:04:37.177 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:04:37.471 [reactor-http-epoll-4] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.101.177 - - [19/Aug/2026:07:04:37 +0000] "GET /api/clusters/kafka-dev/topics?page=1&perPage=25&showInternal=true&search=bll.ems.mesarim.&fts=false HTTP/1.1" 200 12312 297
2026-08-19 07:04:38.383 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/clusters/kafka-dev/topics' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@5b167194
2026-08-19 07:04:38.383 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:04:38.666 [reactor-http-epoll-4] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.101.177 - - [19/Aug/2026:07:04:38 +0000] "GET /api/clusters/kafka-dev/topics?page=1&perPage=25&showInternal=true&search=bll.ems.mesarim.s&fts=false HTTP/1.1" 200 12508 284
2026-08-19 07:04:40.061 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/clusters/kafka-dev/topics' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@5b167194
2026-08-19 07:04:40.061 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:04:40.362 [reactor-http-epoll-4] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.101.177 - - [19/Aug/2026:07:04:40 +0000] "GET /api/clusters/kafka-dev/topics?page=1&perPage=25&showInternal=true&search=bll.ems.mesarim.sa&fts=false HTTP/1.1" 200 5564 302
2026-08-19 07:04:43.765 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/clusters/kafka-dev/topics' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@5b167194
2026-08-19 07:04:43.766 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:04:44.098 [reactor-http-epoll-4] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.101.177 - - [19/Aug/2026:07:04:43 +0000] "GET /api/clusters/kafka-dev/topics?page=1&perPage=25&showInternal=true&search=bll.ems.mesarim.salary&fts=false HTTP/1.1" 200 1036 335
2026-08-19 07:04:45.103 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/clusters/kafka-dev/topics' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@5b167194
2026-08-19 07:04:45.104 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:04:45.441 [reactor-http-epoll-4] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.101.177 - - [19/Aug/2026:07:04:45 +0000] "GET /api/clusters/kafka-dev/topics?page=1&perPage=25&showInternal=true&search=bll.ems.mesarim.salarycredi&fts=false HTTP/1.1" 200 1036 338
2026-08-19 07:04:46.985 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/Topic-DRoA7Yr2.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 07:04:46.985 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:04:46.990 [reactor-http-epoll-1] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/fetch-IOhmRd8d.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 07:04:46.991 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/TableCells-fkcKFKS_.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 07:04:46.991 [reactor-http-epoll-1] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:04:46.991 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:04:46.991 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/utils-CH284mxw.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 07:04:46.992 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:04:46.994 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/BreakableTextCell-DqvTDMqh.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 07:04:46.994 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:04:46.998 [reactor-http-epoll-4] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.101.177 - - [19/Aug/2026:07:04:46 +0000] "GET /assets/utils-CH284mxw.js HTTP/1.1" 200 7596 7
2026-08-19 07:04:47.000 [reactor-http-epoll-4] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.101.177 - - [19/Aug/2026:07:04:46 +0000] "GET /assets/Topic-DRoA7Yr2.js HTTP/1.1" 200 529741 18
2026-08-19 07:04:47.004 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/TopicForm-pYLuj2DS.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 07:04:47.004 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:04:47.007 [reactor-http-epoll-4] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.101.177 - - [19/Aug/2026:07:04:47 +0000] "GET /assets/TopicForm-pYLuj2DS.js HTTP/1.1" 200 14107 3
2026-08-19 07:04:47.010 [reactor-http-epoll-1] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/EditorViewer-VrhowIkD.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 07:04:47.010 [reactor-http-epoll-1] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:04:47.010 [reactor-http-epoll-3] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.101.177 - - [19/Aug/2026:07:04:46 +0000] "GET /assets/TableCells-fkcKFKS_.js HTTP/1.1" 200 7966 19
2026-08-19 07:04:47.011 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/ConnectorsTable-CArCXxZL.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 07:04:47.011 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:04:47.012 [reactor-http-epoll-1] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.101.177 - - [19/Aug/2026:07:04:47 +0000] "GET /assets/EditorViewer-VrhowIkD.js HTTP/1.1" 200 10601 3
2026-08-19 07:04:47.012 [reactor-http-epoll-1] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.101.177 - - [19/Aug/2026:07:04:46 +0000] "GET /assets/fetch-IOhmRd8d.js HTTP/1.1" 200 2478 23
2026-08-19 07:04:47.013 [reactor-http-epoll-4] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.101.177 - - [19/Aug/2026:07:04:47 +0000] "GET /assets/ConnectorsTable-CArCXxZL.js HTTP/1.1" 200 6855 2
2026-08-19 07:04:47.014 [reactor-http-epoll-3] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.101.177 - - [19/Aug/2026:07:04:46 +0000] "GET /assets/BreakableTextCell-DqvTDMqh.js HTTP/1.1" 200 161 21
2026-08-19 07:04:47.084 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/clusters/kafka-dev/topics/bll.ems.mesarim.salaryCredit.pepper.t/connectors' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@5b167194
2026-08-19 07:04:47.084 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:04:47.104 [reactor-http-epoll-4] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.101.177 - - [19/Aug/2026:07:04:47 +0000] "GET /api/clusters/kafka-dev/topics/bll.ems.mesarim.salaryCredit.pepper.t/connectors HTTP/1.1" 200 2 21
2026-08-19 07:04:47.120 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/clusters/kafka-dev/topics/bll.ems.mesarim.salaryCredit.pepper.t/serdes' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@5b167194
2026-08-19 07:04:47.121 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:04:47.182 [reactor-http-epoll-4] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.101.177 - - [19/Aug/2026:07:04:47 +0000] "GET /api/clusters/kafka-dev/topics/bll.ems.mesarim.salaryCredit.pepper.t/serdes?use=SERIALIZE HTTP/1.1" 200 2721 62
2026-08-19 07:04:47.317 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/clusters/kafka-dev/topics/bll.ems.mesarim.salaryCredit.pepper.t' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@5b167194
2026-08-19 07:04:47.317 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:04:48.539 [reactor-http-epoll-4] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.101.177 - - [19/Aug/2026:07:04:47 +0000] "GET /api/clusters/kafka-dev/topics/bll.ems.mesarim.salaryCredit.pepper.t HTTP/1.1" 200 518 1224
2026-08-19 07:04:48.565 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/clusters/kafka-dev/topics/bll.ems.mesarim.salaryCredit.pepper.t' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@5b167194
2026-08-19 07:04:48.566 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:04:48.847 [reactor-http-epoll-4] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.101.177 - - [19/Aug/2026:07:04:48 +0000] "GET /api/clusters/kafka-dev/topics/bll.ems.mesarim.salaryCredit.pepper.t HTTP/1.1" 200 518 283
2026-08-19 07:04:57.514 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/clusters/kafka-dev/topics/bll.ems.mesarim.salaryCredit.pepper.t/messages' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@5b167194
2026-08-19 07:04:57.515 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:04:57.615 [boundedElastic-35] INFO  o.a.k.c.producer.ProducerConfig -  - - ProducerConfig values: 
	acks = -1
	auto.include.jmx.reporter = true
	batch.size = 16384
	bootstrap.servers = [LINX102083TI1:9092]
	buffer.memory = 33554432
	client.dns.lookup = use_all_dns_ips
	client.id = producer-1
	compression.gzip.level = -1
	compression.lz4.level = 9
	compression.type = none
	compression.zstd.level = 3
	connections.max.idle.ms = 540000
	delivery.timeout.ms = 120000
	enable.idempotence = true
	enable.metrics.push = true
	interceptor.classes = []
	key.serializer = class org.apache.kafka.common.serialization.ByteArraySerializer
	linger.ms = 0
	max.block.ms = 60000
	max.in.flight.requests.per.connection = 5
	max.request.size = 1048576
	metadata.max.age.ms = 300000
	metadata.max.idle.ms = 300000
	metadata.recovery.strategy = none
	metric.reporters = []
	metrics.num.samples = 2
	metrics.recording.level = INFO
	metrics.sample.window.ms = 30000
	partitioner.adaptive.partitioning.enable = true
	partitioner.availability.timeout.ms = 0
	partitioner.class = null
	partitioner.ignore.keys = false
	receive.buffer.bytes = 32768
	reconnect.backoff.max.ms = 1000
	reconnect.backoff.ms = 50
	request.timeout.ms = 30000
	retries = 2147483647
	retry.backoff.max.ms = 1000
	retry.backoff.ms = 100
	sasl.client.callback.handler.class = null
	sasl.jaas.config = null
	sasl.kerberos.kinit.cmd = /usr/bin/kinit
	sasl.kerberos.min.time.before.relogin = 60000
	sasl.kerberos.service.name = null
	sasl.kerberos.ticket.renew.jitter = 0.05
	sasl.kerberos.ticket.renew.window.factor = 0.8
	sasl.login.callback.handler.class = null
	sasl.login.class = null
	sasl.login.connect.timeout.ms = null
	sasl.login.read.timeout.ms = null
	sasl.login.refresh.buffer.seconds = 300
	sasl.login.refresh.min.period.seconds = 60
	sasl.login.refresh.window.factor = 0.8
	sasl.login.refresh.window.jitter = 0.05
	sasl.login.retry.backoff.max.ms = 10000
	sasl.login.retry.backoff.ms = 100
	sasl.mechanism = GSSAPI
	sasl.oauthbearer.clock.skew.seconds = 30
	sasl.oauthbearer.expected.audience = null
	sasl.oauthbearer.expected.issuer = null
	sasl.oauthbearer.header.urlencode = false
	sasl.oauthbearer.jwks.endpoint.refresh.ms = 3600000
	sasl.oauthbearer.jwks.endpoint.retry.backoff.max.ms = 10000
	sasl.oauthbearer.jwks.endpoint.retry.backoff.ms = 100
	sasl.oauthbearer.jwks.endpoint.url = null
	sasl.oauthbearer.scope.claim.name = scope
	sasl.oauthbearer.sub.claim.name = sub
	sasl.oauthbearer.token.endpoint.url = null
	security.protocol = PLAINTEXT
	security.providers = null
	send.buffer.bytes = 131072
	socket.connection.setup.timeout.max.ms = 30000
	socket.connection.setup.timeout.ms = 10000
	ssl.cipher.suites = null
	ssl.enabled.protocols = [TLSv1.2, TLSv1.3]
	ssl.endpoint.identification.algorithm = https
	ssl.engine.factory.class = null
	ssl.key.password = null
	ssl.keymanager.algorithm = SunX509
	ssl.keystore.certificate.chain = null
	ssl.keystore.key = null
	ssl.keystore.location = null
	ssl.keystore.password = null
	ssl.keystore.type = JKS
	ssl.protocol = TLSv1.3
	ssl.provider = null
	ssl.secure.random.implementation = null
	ssl.trustmanager.algorithm = PKIX
	ssl.truststore.certificates = null
	ssl.truststore.location = null
	ssl.truststore.password = null
	ssl.truststore.type = JKS
	transaction.timeout.ms = 60000
	transactional.id = null
	value.serializer = class org.apache.kafka.common.serialization.ByteArraySerializer

2026-08-19 07:04:57.646 [boundedElastic-35] INFO  o.a.k.c.t.i.KafkaMetricsCollector -  - - initializing Kafka metrics collector
2026-08-19 07:04:57.657 [boundedElastic-35] INFO  o.a.k.clients.producer.KafkaProducer -  - - [Producer clientId=producer-1] Instantiated an idempotent producer.
2026-08-19 07:04:57.675 [boundedElastic-35] INFO  o.a.kafka.common.utils.AppInfoParser -  - - Kafka version: 7.9.5-ccs
2026-08-19 07:04:57.675 [boundedElastic-35] INFO  o.a.kafka.common.utils.AppInfoParser -  - - Kafka commitId: 4cbb817945d2251e
2026-08-19 07:04:57.675 [boundedElastic-35] INFO  o.a.kafka.common.utils.AppInfoParser -  - - Kafka startTimeMs: 1787123097675
2026-08-19 07:04:57.689 [kafka-producer-network-thread | producer-1] INFO  org.apache.kafka.clients.Metadata -  - - [Producer clientId=producer-1] Cluster ID: 7llUOb1oSwa4TMstH-TbNw
2026-08-19 07:04:57.691 [kafka-producer-network-thread | producer-1] INFO  o.a.k.c.p.i.TransactionManager -  - - [Producer clientId=producer-1] ProducerId set to 1898950 with epoch 0
2026-08-19 07:04:57.702 [boundedElastic-35] INFO  o.a.k.clients.producer.KafkaProducer -  - - [Producer clientId=producer-1] Closing the Kafka producer with timeoutMillis = 9223372036854775807 ms.
2026-08-19 07:04:57.764 [boundedElastic-35] INFO  o.a.kafka.common.metrics.Metrics -  - - Metrics scheduler closed
2026-08-19 07:04:57.764 [boundedElastic-35] INFO  o.a.kafka.common.metrics.Metrics -  - - Closing reporter org.apache.kafka.common.metrics.JmxReporter
2026-08-19 07:04:57.764 [boundedElastic-35] INFO  o.a.kafka.common.metrics.Metrics -  - - Closing reporter org.apache.kafka.common.telemetry.internals.ClientTelemetryReporter
2026-08-19 07:04:57.764 [boundedElastic-35] INFO  o.a.kafka.common.metrics.Metrics -  - - Metrics reporters closed
2026-08-19 07:04:57.765 [boundedElastic-35] INFO  o.a.kafka.common.utils.AppInfoParser -  - - App info kafka.producer for producer-1 unregistered
2026-08-19 07:04:57.767 [reactor-http-epoll-4] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.101.177 - - [19/Aug/2026:07:04:57 +0000] "POST /api/clusters/kafka-dev/topics/bll.ems.mesarim.salaryCredit.pepper.t/messages HTTP/1.1" 200 0 255
2026-08-19 07:04:57.784 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/clusters/kafka-dev/topics/bll.ems.mesarim.salaryCredit.pepper.t' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@5b167194
2026-08-19 07:04:57.785 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:04:57.786 [reactor-http-epoll-1] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/clusters/kafka-dev/topics/bll.ems.mesarim.salaryCredit.pepper.t/connectors' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@5b167194
2026-08-19 07:04:57.786 [reactor-http-epoll-1] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:04:57.790 [reactor-http-epoll-1] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/clusters/kafka-dev/topics/bll.ems.mesarim.salaryCredit.pepper.t/serdes' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@5b167194
2026-08-19 07:04:57.790 [reactor-http-epoll-1] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:04:57.797 [reactor-http-epoll-1] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.101.177 - - [19/Aug/2026:07:04:57 +0000] "GET /api/clusters/kafka-dev/topics/bll.ems.mesarim.salaryCredit.pepper.t/connectors HTTP/1.1" 200 2 11
2026-08-19 07:04:57.798 [reactor-http-epoll-1] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.101.177 - - [19/Aug/2026:07:04:57 +0000] "GET /api/clusters/kafka-dev/topics/bll.ems.mesarim.salaryCredit.pepper.t/serdes?use=SERIALIZE HTTP/1.1" 200 2721 8
2026-08-19 07:04:58.050 [reactor-http-epoll-4] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.101.177 - - [19/Aug/2026:07:04:57 +0000] "GET /api/clusters/kafka-dev/topics/bll.ems.mesarim.salaryCredit.pepper.t HTTP/1.1" 200 518 268
2026-08-19 07:06:01.588 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/clusters/kafka-dev/topics/bll.ems.mesarim.salaryCredit.pepper.t/connectors' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@5b167194
2026-08-19 07:06:01.588 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/info' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@5b167194
2026-08-19 07:06:01.588 [reactor-http-epoll-1] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/clusters' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@5b167194
2026-08-19 07:06:01.589 [reactor-http-epoll-1] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:06:01.589 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:06:01.589 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:06:01.591 [reactor-http-epoll-4] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.101.177 - - [19/Aug/2026:07:06:01 +0000] "GET /api/info HTTP/1.1" 200 205 5
2026-08-19 07:06:01.593 [reactor-http-epoll-1] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.101.177 - - [19/Aug/2026:07:06:01 +0000] "GET /api/clusters HTTP/1.1" 200 347 7
2026-08-19 07:06:01.593 [reactor-http-epoll-1] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/clusters/kafka-dev/topics/bll.ems.mesarim.salaryCredit.pepper.t' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@5b167194
2026-08-19 07:06:01.593 [reactor-http-epoll-1] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:06:01.594 [reactor-http-epoll-3] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.101.177 - - [19/Aug/2026:07:06:01 +0000] "GET /api/clusters/kafka-dev/topics/bll.ems.mesarim.salaryCredit.pepper.t/connectors HTTP/1.1" 200 2 7
2026-08-19 07:06:01.900 [reactor-http-epoll-1] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.101.177 - - [19/Aug/2026:07:06:01 +0000] "GET /api/clusters/kafka-dev/topics/bll.ems.mesarim.salaryCredit.pepper.t HTTP/1.1" 200 518 307
2026-08-19 07:10:09.444 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/clusters/kafka-dev/topics/bll.ems.mesarim.salaryCredit.pepper.t' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@5b167194
2026-08-19 07:10:09.444 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/clusters/kafka-dev/topics/bll.ems.mesarim.salaryCredit.pepper.t/connectors' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@5b167194
2026-08-19 07:10:09.444 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:10:09.444 [reactor-http-epoll-1] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/info' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@5b167194
2026-08-19 07:10:09.444 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:10:09.445 [reactor-http-epoll-1] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:10:09.448 [reactor-http-epoll-1] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.101.177 - - [19/Aug/2026:07:10:09 +0000] "GET /api/info HTTP/1.1" 200 205 6
2026-08-19 07:10:09.448 [reactor-http-epoll-4] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.101.177 - - [19/Aug/2026:07:10:09 +0000] "GET /api/clusters/kafka-dev/topics/bll.ems.mesarim.salaryCredit.pepper.t/connectors HTTP/1.1" 200 2 4
2026-08-19 07:10:09.449 [reactor-http-epoll-1] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/clusters' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@5b167194
2026-08-19 07:10:09.449 [reactor-http-epoll-1] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:10:09.452 [reactor-http-epoll-1] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.101.177 - - [19/Aug/2026:07:10:09 +0000] "GET /api/clusters HTTP/1.1" 200 347 4
2026-08-19 07:10:09.742 [reactor-http-epoll-3] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.101.177 - - [19/Aug/2026:07:10:09 +0000] "GET /api/clusters/kafka-dev/topics/bll.ems.mesarim.salaryCredit.pepper.t HTTP/1.1" 200 518 299
2026-08-19 07:10:13.886 [reactor-http-epoll-1] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/clusters' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@5b167194
2026-08-19 07:10:13.886 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/info' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@5b167194
2026-08-19 07:10:13.886 [reactor-http-epoll-1] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:10:13.886 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:10:13.886 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/clusters/kafka-dev/topics/bll.ems.mesarim.salaryCredit.pepper.t/connectors' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@5b167194
2026-08-19 07:10:13.887 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:10:13.890 [reactor-http-epoll-3] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.101.177 - - [19/Aug/2026:07:10:13 +0000] "GET /api/info HTTP/1.1" 200 205 7
2026-08-19 07:10:13.890 [reactor-http-epoll-1] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.101.177 - - [19/Aug/2026:07:10:13 +0000] "GET /api/clusters HTTP/1.1" 200 347 7
2026-08-19 07:10:13.890 [reactor-http-epoll-4] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.101.177 - - [19/Aug/2026:07:10:13 +0000] "GET /api/clusters/kafka-dev/topics/bll.ems.mesarim.salaryCredit.pepper.t/connectors HTTP/1.1" 200 2 5
2026-08-19 07:10:13.891 [reactor-http-epoll-1] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/clusters/kafka-dev/topics/bll.ems.mesarim.salaryCredit.pepper.t' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@5b167194
2026-08-19 07:10:13.891 [reactor-http-epoll-1] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:10:14.175 [reactor-http-epoll-1] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.101.177 - - [19/Aug/2026:07:10:13 +0000] "GET /api/clusters/kafka-dev/topics/bll.ems.mesarim.salaryCredit.pepper.t HTTP/1.1" 200 518 284
2026-08-19 07:10:29.549 [reactor-http-epoll-1] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/info' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@5b167194
2026-08-19 07:10:29.549 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/clusters/kafka-dev/topics/bll.ems.mesarim.salaryCredit.pepper.t' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@5b167194
2026-08-19 07:10:29.550 [reactor-http-epoll-1] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:10:29.550 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:10:29.551 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/clusters/kafka-dev/topics/bll.ems.mesarim.salaryCredit.pepper.t/connectors' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@5b167194
2026-08-19 07:10:29.551 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:10:29.553 [reactor-http-epoll-1] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.101.177 - - [19/Aug/2026:07:10:29 +0000] "GET /api/info HTTP/1.1" 200 205 6
2026-08-19 07:10:29.554 [reactor-http-epoll-3] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.101.177 - - [19/Aug/2026:07:10:29 +0000] "GET /api/clusters/kafka-dev/topics/bll.ems.mesarim.salaryCredit.pepper.t/connectors HTTP/1.1" 200 2 3
2026-08-19 07:10:29.554 [reactor-http-epoll-1] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/clusters' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@5b167194
2026-08-19 07:10:29.554 [reactor-http-epoll-1] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:10:29.557 [reactor-http-epoll-1] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.101.177 - - [19/Aug/2026:07:10:29 +0000] "GET /api/clusters HTTP/1.1" 200 347 4
2026-08-19 07:10:29.824 [reactor-http-epoll-4] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.101.177 - - [19/Aug/2026:07:10:29 +0000] "GET /api/clusters/kafka-dev/topics/bll.ems.mesarim.salaryCredit.pepper.t HTTP/1.1" 200 518 275
2026-08-19 07:10:36.271 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/clusters/kafka-dev/topics/bll.ems.mesarim.salaryCredit.pepper.t/messages' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@5b167194
2026-08-19 07:10:36.271 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:10:36.281 [boundedElastic-36] INFO  o.a.k.c.producer.ProducerConfig -  - - ProducerConfig values: 
	acks = -1
	auto.include.jmx.reporter = true
	batch.size = 16384
	bootstrap.servers = [LINX102083TI1:9092]
	buffer.memory = 33554432
	client.dns.lookup = use_all_dns_ips
	client.id = producer-2
	compression.gzip.level = -1
	compression.lz4.level = 9
	compression.type = none
	compression.zstd.level = 3
	connections.max.idle.ms = 540000
	delivery.timeout.ms = 120000
	enable.idempotence = true
	enable.metrics.push = true
	interceptor.classes = []
	key.serializer = class org.apache.kafka.common.serialization.ByteArraySerializer
	linger.ms = 0
	max.block.ms = 60000
	max.in.flight.requests.per.connection = 5
	max.request.size = 1048576
	metadata.max.age.ms = 300000
	metadata.max.idle.ms = 300000
	metadata.recovery.strategy = none
	metric.reporters = []
	metrics.num.samples = 2
	metrics.recording.level = INFO
	metrics.sample.window.ms = 30000
	partitioner.adaptive.partitioning.enable = true
	partitioner.availability.timeout.ms = 0
	partitioner.class = null
	partitioner.ignore.keys = false
	receive.buffer.bytes = 32768
	reconnect.backoff.max.ms = 1000
	reconnect.backoff.ms = 50
	request.timeout.ms = 30000
	retries = 2147483647
	retry.backoff.max.ms = 1000
	retry.backoff.ms = 100
	sasl.client.callback.handler.class = null
	sasl.jaas.config = null
	sasl.kerberos.kinit.cmd = /usr/bin/kinit
	sasl.kerberos.min.time.before.relogin = 60000
	sasl.kerberos.service.name = null
	sasl.kerberos.ticket.renew.jitter = 0.05
	sasl.kerberos.ticket.renew.window.factor = 0.8
	sasl.login.callback.handler.class = null
	sasl.login.class = null
	sasl.login.connect.timeout.ms = null
	sasl.login.read.timeout.ms = null
	sasl.login.refresh.buffer.seconds = 300
	sasl.login.refresh.min.period.seconds = 60
	sasl.login.refresh.window.factor = 0.8
	sasl.login.refresh.window.jitter = 0.05
	sasl.login.retry.backoff.max.ms = 10000
	sasl.login.retry.backoff.ms = 100
	sasl.mechanism = GSSAPI
	sasl.oauthbearer.clock.skew.seconds = 30
	sasl.oauthbearer.expected.audience = null
	sasl.oauthbearer.expected.issuer = null
	sasl.oauthbearer.header.urlencode = false
	sasl.oauthbearer.jwks.endpoint.refresh.ms = 3600000
	sasl.oauthbearer.jwks.endpoint.retry.backoff.max.ms = 10000
	sasl.oauthbearer.jwks.endpoint.retry.backoff.ms = 100
	sasl.oauthbearer.jwks.endpoint.url = null
	sasl.oauthbearer.scope.claim.name = scope
	sasl.oauthbearer.sub.claim.name = sub
	sasl.oauthbearer.token.endpoint.url = null
	security.protocol = PLAINTEXT
	security.providers = null
	send.buffer.bytes = 131072
	socket.connection.setup.timeout.max.ms = 30000
	socket.connection.setup.timeout.ms = 10000
	ssl.cipher.suites = null
	ssl.enabled.protocols = [TLSv1.2, TLSv1.3]
	ssl.endpoint.identification.algorithm = https
	ssl.engine.factory.class = null
	ssl.key.password = null
	ssl.keymanager.algorithm = SunX509
	ssl.keystore.certificate.chain = null
	ssl.keystore.key = null
	ssl.keystore.location = null
	ssl.keystore.password = null
	ssl.keystore.type = JKS
	ssl.protocol = TLSv1.3
	ssl.provider = null
	ssl.secure.random.implementation = null
	ssl.trustmanager.algorithm = PKIX
	ssl.truststore.certificates = null
	ssl.truststore.location = null
	ssl.truststore.password = null
	ssl.truststore.type = JKS
	transaction.timeout.ms = 60000
	transactional.id = null
	value.serializer = class org.apache.kafka.common.serialization.ByteArraySerializer

2026-08-19 07:10:36.281 [boundedElastic-36] INFO  o.a.k.c.t.i.KafkaMetricsCollector -  - - initializing Kafka metrics collector
2026-08-19 07:10:36.282 [boundedElastic-36] INFO  o.a.k.clients.producer.KafkaProducer -  - - [Producer clientId=producer-2] Instantiated an idempotent producer.
2026-08-19 07:10:36.289 [boundedElastic-36] INFO  o.a.kafka.common.utils.AppInfoParser -  - - Kafka version: 7.9.5-ccs
2026-08-19 07:10:36.289 [boundedElastic-36] INFO  o.a.kafka.common.utils.AppInfoParser -  - - Kafka commitId: 4cbb817945d2251e
2026-08-19 07:10:36.289 [boundedElastic-36] INFO  o.a.kafka.common.utils.AppInfoParser -  - - Kafka startTimeMs: 1787123436289
2026-08-19 07:10:36.294 [kafka-producer-network-thread | producer-2] INFO  org.apache.kafka.clients.Metadata -  - - [Producer clientId=producer-2] Cluster ID: 7llUOb1oSwa4TMstH-TbNw
2026-08-19 07:10:36.294 [kafka-producer-network-thread | producer-2] INFO  o.a.k.c.p.i.TransactionManager -  - - [Producer clientId=producer-2] ProducerId set to 1898951 with epoch 0
2026-08-19 07:10:36.294 [boundedElastic-36] INFO  o.a.k.clients.producer.KafkaProducer -  - - [Producer clientId=producer-2] Closing the Kafka producer with timeoutMillis = 9223372036854775807 ms.
2026-08-19 07:10:36.312 [boundedElastic-36] INFO  o.a.kafka.common.metrics.Metrics -  - - Metrics scheduler closed
2026-08-19 07:10:36.312 [boundedElastic-36] INFO  o.a.kafka.common.metrics.Metrics -  - - Closing reporter org.apache.kafka.common.metrics.JmxReporter
2026-08-19 07:10:36.312 [boundedElastic-36] INFO  o.a.kafka.common.metrics.Metrics -  - - Closing reporter org.apache.kafka.common.telemetry.internals.ClientTelemetryReporter
2026-08-19 07:10:36.312 [boundedElastic-36] INFO  o.a.kafka.common.metrics.Metrics -  - - Metrics reporters closed
2026-08-19 07:10:36.312 [boundedElastic-36] INFO  o.a.kafka.common.utils.AppInfoParser -  - - App info kafka.producer for producer-2 unregistered
2026-08-19 07:10:36.313 [reactor-http-epoll-4] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.101.177 - - [19/Aug/2026:07:10:36 +0000] "POST /api/clusters/kafka-dev/topics/bll.ems.mesarim.salaryCredit.pepper.t/messages HTTP/1.1" 200 0 43
2026-08-19 07:10:36.324 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/clusters/kafka-dev/topics/bll.ems.mesarim.salaryCredit.pepper.t' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@5b167194
2026-08-19 07:10:36.324 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:10:36.325 [reactor-http-epoll-1] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/clusters/kafka-dev/topics/bll.ems.mesarim.salaryCredit.pepper.t/connectors' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@5b167194
2026-08-19 07:10:36.325 [reactor-http-epoll-1] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:10:36.327 [reactor-http-epoll-1] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.101.177 - - [19/Aug/2026:07:10:36 +0000] "GET /api/clusters/kafka-dev/topics/bll.ems.mesarim.salaryCredit.pepper.t/connectors HTTP/1.1" 200 2 2
2026-08-19 07:10:36.328 [reactor-http-epoll-1] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/clusters/kafka-dev/topics/bll.ems.mesarim.salaryCredit.pepper.t/serdes' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@5b167194
2026-08-19 07:10:36.328 [reactor-http-epoll-1] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:10:36.330 [reactor-http-epoll-1] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.101.177 - - [19/Aug/2026:07:10:36 +0000] "GET /api/clusters/kafka-dev/topics/bll.ems.mesarim.salaryCredit.pepper.t/serdes?use=SERIALIZE HTTP/1.1" 200 2721 3
2026-08-19 07:10:36.600 [reactor-http-epoll-4] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.101.177 - - [19/Aug/2026:07:10:36 +0000] "GET /api/clusters/kafka-dev/topics/bll.ems.mesarim.salaryCredit.pepper.t HTTP/1.1" 200 518 277
2026-08-19 07:13:38.782 [parallel-2] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@5b167194
2026-08-19 07:13:38.783 [parallel-2] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization failed: Access Denied
2026-08-19 07:13:38.785 [reactor-http-epoll-3] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.98.81 - - [19/Aug/2026:07:13:38 +0000] "GET / HTTP/1.1" 302 0 6
2026-08-19 07:13:38.796 [reactor-http-epoll-3] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.98.81 - - [19/Aug/2026:07:13:38 +0000] "GET /login HTTP/1.1" 200 1816 1
2026-08-19 07:13:38.831 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/index-ToFdRV4e.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 07:13:38.831 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:13:38.831 [reactor-http-epoll-2] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/@react-router-D-4KBoK_.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 07:13:38.831 [reactor-http-epoll-2] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:13:38.837 [reactor-http-epoll-2] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.98.81 - - [19/Aug/2026:07:13:38 +0000] "GET /assets/@react-router-D-4KBoK_.js HTTP/1.1" 200 166169 6
2026-08-19 07:13:38.841 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/index-D3Fzj2d9.css' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 07:13:38.841 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:13:38.843 [reactor-http-epoll-4] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.98.81 - - [19/Aug/2026:07:13:38 +0000] "GET /assets/index-D3Fzj2d9.css HTTP/1.1" 200 1617 3
2026-08-19 07:13:38.845 [reactor-http-epoll-3] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.98.81 - - [19/Aug/2026:07:13:38 +0000] "GET /assets/index-ToFdRV4e.js HTTP/1.1" 200 344993 15
2026-08-19 07:13:38.984 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/AuthPage-DYy823dD.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 07:13:38.984 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/AlertIcon-CaXsK92Y.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 07:13:38.984 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:13:38.984 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:13:38.987 [reactor-http-epoll-4] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.98.81 - - [19/Aug/2026:07:13:38 +0000] "GET /assets/AlertIcon-CaXsK92Y.js HTTP/1.1" 200 684 4
2026-08-19 07:13:38.988 [reactor-http-epoll-3] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.98.81 - - [19/Aug/2026:07:13:38 +0000] "GET /assets/AuthPage-DYy823dD.js HTTP/1.1" 200 23430 5
2026-08-19 07:13:39.003 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/config/authentication' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 07:13:39.003 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:13:39.006 [reactor-http-epoll-3] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.98.81 - - [19/Aug/2026:07:13:39 +0000] "GET /api/config/authentication HTTP/1.1" 200 39 3
2026-08-19 07:13:39.008 [parallel-3] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/manifest.json' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 07:13:39.008 [parallel-3] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:13:39.009 [reactor-http-epoll-1] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.98.81 - - [19/Aug/2026:07:13:39 +0000] "GET /manifest.json HTTP/1.1" 200 249 2
2026-08-19 07:13:39.078 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/fonts/Inter-Medium.ttf' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 07:13:39.078 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:13:39.085 [reactor-http-epoll-3] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.98.81 - - [19/Aug/2026:07:13:39 +0000] "GET /fonts/Inter-Medium.ttf HTTP/1.1" 200 308392 8
2026-08-19 07:13:39.101 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/fonts/Inter-Regular.ttf' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 07:13:39.101 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:13:39.105 [reactor-http-epoll-3] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.98.81 - - [19/Aug/2026:07:13:39 +0000] "GET /fonts/Inter-Regular.ttf HTTP/1.1" 200 303504 5
2026-08-19 07:13:52.113 [reactor-http-epoll-3] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.98.81 - - [19/Aug/2026:07:13:51 +0000] "POST /login HTTP/1.1" 302 0 1112
2026-08-19 07:13:52.119 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@5b167194
2026-08-19 07:13:52.119 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:13:52.121 [reactor-http-epoll-3] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.98.81 - - [19/Aug/2026:07:13:52 +0000] "GET / HTTP/1.1" 200 1816 3
2026-08-19 07:13:52.148 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/info' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@5b167194
2026-08-19 07:13:52.148 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:13:52.150 [reactor-http-epoll-3] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.98.81 - - [19/Aug/2026:07:13:52 +0000] "GET /api/info HTTP/1.1" 200 205 3
2026-08-19 07:13:52.172 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/authorization' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 07:13:52.172 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:13:52.174 [reactor-http-epoll-3] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.98.81 - - [19/Aug/2026:07:13:52 +0000] "GET /api/authorization HTTP/1.1" 200 894 3
2026-08-19 07:13:52.220 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/info' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@5b167194
2026-08-19 07:13:52.220 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:13:52.222 [reactor-http-epoll-3] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.98.81 - - [19/Aug/2026:07:13:52 +0000] "GET /api/info HTTP/1.1" 200 205 3
2026-08-19 07:13:52.243 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/Dashboard-949avtj_.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 07:13:52.243 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:13:52.243 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/ActionComponent.styled-CtMfGuhc.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 07:13:52.243 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:13:52.244 [reactor-http-epoll-2] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/Heading.styled-DGSlQalk.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 07:13:52.244 [reactor-http-epoll-2] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:13:52.246 [reactor-http-epoll-2] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.98.81 - - [19/Aug/2026:07:13:52 +0000] "GET /assets/Heading.styled-DGSlQalk.js HTTP/1.1" 200 285 2
2026-08-19 07:13:52.247 [reactor-http-epoll-3] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.98.81 - - [19/Aug/2026:07:13:52 +0000] "GET /assets/Dashboard-949avtj_.js HTTP/1.1" 200 3137 5
2026-08-19 07:13:52.248 [reactor-http-epoll-4] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.98.81 - - [19/Aug/2026:07:13:52 +0000] "GET /assets/ActionComponent.styled-CtMfGuhc.js HTTP/1.1" 200 119533 5
2026-08-19 07:13:52.252 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/SizeCell-C-hVT6uc.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 07:13:52.252 [reactor-http-epoll-2] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/Switch-DR0XBu1-.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 07:13:52.253 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:13:52.253 [reactor-http-epoll-2] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:13:52.255 [reactor-http-epoll-2] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.98.81 - - [19/Aug/2026:07:13:52 +0000] "GET /assets/Switch-DR0XBu1-.js HTTP/1.1" 200 1130 3
2026-08-19 07:13:52.255 [reactor-http-epoll-3] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.98.81 - - [19/Aug/2026:07:13:52 +0000] "GET /assets/SizeCell-C-hVT6uc.js HTTP/1.1" 200 176 3
2026-08-19 07:13:52.256 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/ActionCanButton-BCx801KA.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 07:13:52.256 [reactor-http-epoll-2] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/BytesFormatted-QhqsAXvV.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 07:13:52.256 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:13:52.256 [reactor-http-epoll-2] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:13:52.257 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/localStoragePersister-D-viOm25.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 07:13:52.257 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:13:52.258 [reactor-http-epoll-3] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.98.81 - - [19/Aug/2026:07:13:52 +0000] "GET /assets/ActionCanButton-BCx801KA.js HTTP/1.1" 200 456 3
2026-08-19 07:13:52.258 [reactor-http-epoll-2] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.98.81 - - [19/Aug/2026:07:13:52 +0000] "GET /assets/BytesFormatted-QhqsAXvV.js HTTP/1.1" 200 591 3
2026-08-19 07:13:52.258 [reactor-http-epoll-4] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.98.81 - - [19/Aug/2026:07:13:52 +0000] "GET /assets/localStoragePersister-D-viOm25.js HTTP/1.1" 200 590 2
2026-08-19 07:13:52.310 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/clusters' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@5b167194
2026-08-19 07:13:52.310 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:13:52.313 [reactor-http-epoll-4] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.98.81 - - [19/Aug/2026:07:13:52 +0000] "GET /api/clusters HTTP/1.1" 200 347 3
2026-08-19 07:14:10.437 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/info' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@5b167194
2026-08-19 07:14:10.437 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/clusters' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@5b167194
2026-08-19 07:14:10.438 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:14:10.438 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:14:10.439 [reactor-http-epoll-4] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.98.81 - - [19/Aug/2026:07:14:10 +0000] "GET /api/info HTTP/1.1" 200 205 2
2026-08-19 07:14:10.440 [reactor-http-epoll-3] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.98.81 - - [19/Aug/2026:07:14:10 +0000] "GET /api/clusters HTTP/1.1" 200 347 3
2026-08-19 07:14:12.812 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/info' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@5b167194
2026-08-19 07:14:12.812 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:14:12.813 [reactor-http-epoll-3] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.98.81 - - [19/Aug/2026:07:14:12 +0000] "GET /api/info HTTP/1.1" 200 205 2
2026-08-19 07:14:12.817 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/clusters' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@5b167194
2026-08-19 07:14:12.817 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:14:12.819 [reactor-http-epoll-4] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.98.81 - - [19/Aug/2026:07:14:12 +0000] "GET /api/clusters HTTP/1.1" 200 347 3
2026-08-19 07:15:55.225 [reactor-http-epoll-1] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/clusters' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@5b167194
2026-08-19 07:15:55.225 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/clusters/kafka-dev/topics/bll.ems.mesarim.salaryCredit.pepper.t/connectors' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@5b167194
2026-08-19 07:15:55.225 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:15:55.226 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/clusters/kafka-dev/topics/bll.ems.mesarim.salaryCredit.pepper.t' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@5b167194
2026-08-19 07:15:55.225 [reactor-http-epoll-2] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/info' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@5b167194
2026-08-19 07:15:55.226 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:15:55.226 [reactor-http-epoll-2] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:15:55.225 [reactor-http-epoll-1] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:15:55.229 [reactor-http-epoll-2] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.101.177 - - [19/Aug/2026:07:15:55 +0000] "GET /api/info HTTP/1.1" 200 205 6
2026-08-19 07:15:55.229 [reactor-http-epoll-4] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.101.177 - - [19/Aug/2026:07:15:55 +0000] "GET /api/clusters/kafka-dev/topics/bll.ems.mesarim.salaryCredit.pepper.t/connectors HTTP/1.1" 200 2 4
2026-08-19 07:15:55.231 [reactor-http-epoll-1] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.101.177 - - [19/Aug/2026:07:15:55 +0000] "GET /api/clusters HTTP/1.1" 200 347 8
2026-08-19 07:15:55.511 [reactor-http-epoll-3] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.101.177 - - [19/Aug/2026:07:15:55 +0000] "GET /api/clusters/kafka-dev/topics/bll.ems.mesarim.salaryCredit.pepper.t HTTP/1.1" 200 518 285
2026-08-19 07:16:04.194 [reactor-http-epoll-3] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.104.143 - - [19/Aug/2026:07:16:04 +0000] "GET /login HTTP/1.1" 200 1816 3
2026-08-19 07:16:04.323 [parallel-1] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/index-ToFdRV4e.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 07:16:04.323 [parallel-1] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:16:04.330 [reactor-http-epoll-3] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.104.143 - - [19/Aug/2026:07:16:04 +0000] "GET /assets/index-ToFdRV4e.js HTTP/1.1" 200 344993 9
2026-08-19 07:16:04.336 [parallel-2] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/@react-router-D-4KBoK_.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 07:16:04.336 [parallel-2] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:16:04.340 [reactor-http-epoll-3] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.104.143 - - [19/Aug/2026:07:16:04 +0000] "GET /assets/@react-router-D-4KBoK_.js HTTP/1.1" 200 166169 5
2026-08-19 07:16:04.341 [parallel-3] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/index-D3Fzj2d9.css' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 07:16:04.341 [parallel-3] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:16:04.343 [reactor-http-epoll-2] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.104.143 - - [19/Aug/2026:07:16:04 +0000] "GET /assets/index-D3Fzj2d9.css HTTP/1.1" 200 1617 4
2026-08-19 07:16:04.463 [parallel-4] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/AuthPage-DYy823dD.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 07:16:04.463 [parallel-4] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:16:04.463 [parallel-1] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/AlertIcon-CaXsK92Y.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 07:16:04.464 [parallel-1] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:16:04.467 [reactor-http-epoll-2] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.104.143 - - [19/Aug/2026:07:16:04 +0000] "GET /assets/AuthPage-DYy823dD.js HTTP/1.1" 200 23430 5
2026-08-19 07:16:04.468 [reactor-http-epoll-3] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.104.143 - - [19/Aug/2026:07:16:04 +0000] "GET /assets/AlertIcon-CaXsK92Y.js HTTP/1.1" 200 684 5
2026-08-19 07:16:04.482 [parallel-2] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/config/authentication' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 07:16:04.482 [parallel-2] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:16:04.484 [reactor-http-epoll-3] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.104.143 - - [19/Aug/2026:07:16:04 +0000] "GET /api/config/authentication HTTP/1.1" 200 39 3
2026-08-19 07:16:04.551 [parallel-3] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/fonts/Inter-Medium.ttf' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 07:16:04.552 [parallel-3] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:16:04.557 [reactor-http-epoll-3] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.104.143 - - [19/Aug/2026:07:16:04 +0000] "GET /fonts/Inter-Medium.ttf HTTP/1.1" 200 308392 6
2026-08-19 07:16:04.557 [parallel-4] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/fonts/Inter-Regular.ttf' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 07:16:04.558 [parallel-4] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:16:04.562 [reactor-http-epoll-2] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.104.143 - - [19/Aug/2026:07:16:04 +0000] "GET /fonts/Inter-Regular.ttf HTTP/1.1" 200 303504 5
2026-08-19 07:16:42.630 [reactor-http-epoll-2] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.104.143 - - [19/Aug/2026:07:16:41 +0000] "POST /login HTTP/1.1" 302 0 803
2026-08-19 07:16:42.635 [reactor-http-epoll-2] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@5b167194
2026-08-19 07:16:42.636 [reactor-http-epoll-2] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:16:42.638 [reactor-http-epoll-2] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.104.143 - - [19/Aug/2026:07:16:42 +0000] "GET / HTTP/1.1" 200 1816 3
2026-08-19 07:16:42.671 [reactor-http-epoll-2] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/info' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@5b167194
2026-08-19 07:16:42.671 [reactor-http-epoll-2] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:16:42.673 [reactor-http-epoll-2] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.104.143 - - [19/Aug/2026:07:16:42 +0000] "GET /api/info HTTP/1.1" 200 205 3
2026-08-19 07:16:42.704 [reactor-http-epoll-2] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/authorization' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 07:16:42.704 [reactor-http-epoll-2] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:16:42.706 [reactor-http-epoll-2] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.104.143 - - [19/Aug/2026:07:16:42 +0000] "GET /api/authorization HTTP/1.1" 200 1013 2
2026-08-19 07:16:42.748 [reactor-http-epoll-2] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/info' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@5b167194
2026-08-19 07:16:42.748 [reactor-http-epoll-2] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:16:42.749 [reactor-http-epoll-2] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.104.143 - - [19/Aug/2026:07:16:42 +0000] "GET /api/info HTTP/1.1" 200 205 2
2026-08-19 07:16:42.768 [reactor-http-epoll-2] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/Dashboard-949avtj_.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 07:16:42.768 [reactor-http-epoll-2] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:16:42.770 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/ActionComponent.styled-CtMfGuhc.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 07:16:42.770 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:16:42.771 [reactor-http-epoll-2] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.104.143 - - [19/Aug/2026:07:16:42 +0000] "GET /assets/Dashboard-949avtj_.js HTTP/1.1" 200 3137 3
2026-08-19 07:16:42.771 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/Heading.styled-DGSlQalk.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 07:16:42.772 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:16:42.773 [reactor-http-epoll-3] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.104.143 - - [19/Aug/2026:07:16:42 +0000] "GET /assets/Heading.styled-DGSlQalk.js HTTP/1.1" 200 285 2
2026-08-19 07:16:42.774 [reactor-http-epoll-3] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.104.143 - - [19/Aug/2026:07:16:42 +0000] "GET /assets/ActionComponent.styled-CtMfGuhc.js HTTP/1.1" 200 119533 5
2026-08-19 07:16:42.775 [reactor-http-epoll-2] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/Switch-DR0XBu1-.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 07:16:42.775 [reactor-http-epoll-2] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:16:42.776 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/SizeCell-C-hVT6uc.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 07:16:42.777 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:16:42.778 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/BytesFormatted-QhqsAXvV.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 07:16:42.778 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:16:42.780 [reactor-http-epoll-3] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.104.143 - - [19/Aug/2026:07:16:42 +0000] "GET /assets/SizeCell-C-hVT6uc.js HTTP/1.1" 200 176 4
2026-08-19 07:16:42.781 [reactor-http-epoll-3] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.104.143 - - [19/Aug/2026:07:16:42 +0000] "GET /assets/BytesFormatted-QhqsAXvV.js HTTP/1.1" 200 591 3
2026-08-19 07:16:42.781 [reactor-http-epoll-2] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.104.143 - - [19/Aug/2026:07:16:42 +0000] "GET /assets/Switch-DR0XBu1-.js HTTP/1.1" 200 1130 7
2026-08-19 07:16:42.782 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/ActionCanButton-BCx801KA.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 07:16:42.782 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:16:42.784 [reactor-http-epoll-3] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.104.143 - - [19/Aug/2026:07:16:42 +0000] "GET /assets/ActionCanButton-BCx801KA.js HTTP/1.1" 200 456 2
2026-08-19 07:16:42.785 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/localStoragePersister-D-viOm25.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 07:16:42.785 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:16:42.787 [reactor-http-epoll-3] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.104.143 - - [19/Aug/2026:07:16:42 +0000] "GET /assets/localStoragePersister-D-viOm25.js HTTP/1.1" 200 590 3
2026-08-19 07:16:42.857 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/clusters' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@5b167194
2026-08-19 07:16:42.858 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:16:42.861 [reactor-http-epoll-3] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.104.143 - - [19/Aug/2026:07:16:42 +0000] "GET /api/clusters HTTP/1.1" 200 347 4
2026-08-19 07:16:45.216 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/ClusterPage-gx6pMY3q.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 07:16:45.217 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:16:45.216 [reactor-http-epoll-2] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/ace-Bj5lQZzX.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 07:16:45.217 [reactor-http-epoll-2] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:16:45.220 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/index.esm-BgXUD10i.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 07:16:45.221 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:16:45.222 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/ErrorPage-D3l2PA1n.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 07:16:45.223 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:16:45.228 [reactor-http-epoll-2] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.104.143 - - [19/Aug/2026:07:16:45 +0000] "GET /assets/ace-Bj5lQZzX.js HTTP/1.1" 200 578640 14
2026-08-19 07:16:45.236 [reactor-http-epoll-3] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.104.143 - - [19/Aug/2026:07:16:45 +0000] "GET /assets/index.esm-BgXUD10i.js HTTP/1.1" 200 45613 16
2026-08-19 07:16:45.238 [reactor-http-epoll-3] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.104.143 - - [19/Aug/2026:07:16:45 +0000] "GET /assets/ClusterPage-gx6pMY3q.js HTTP/1.1" 200 32435 24
2026-08-19 07:16:45.260 [reactor-http-epoll-3] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.104.143 - - [19/Aug/2026:07:16:45 +0000] "GET /assets/ErrorPage-D3l2PA1n.js HTTP/1.1" 200 1352648 38
2026-08-19 07:16:45.295 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/Topics-omnPFAqB.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 07:16:45.295 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:16:45.298 [reactor-http-epoll-3] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.104.143 - - [19/Aug/2026:07:16:45 +0000] "GET /assets/Topics-omnPFAqB.js HTTP/1.1" 200 3408 4
2026-08-19 07:16:45.307 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/Search-D1de03s6.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 07:16:45.307 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:16:45.308 [reactor-http-epoll-2] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/ControlPanel.styled-CWc6yswd.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 07:16:45.308 [reactor-http-epoll-2] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:16:45.309 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/ActionButton-COAQ-YGZ.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 07:16:45.309 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:16:45.310 [reactor-http-epoll-2] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.104.143 - - [19/Aug/2026:07:16:45 +0000] "GET /assets/ControlPanel.styled-CWc6yswd.js HTTP/1.1" 200 3505 3
2026-08-19 07:16:45.312 [reactor-http-epoll-2] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/PlusIcon-ZsK0o-cX.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 07:16:45.312 [reactor-http-epoll-2] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:16:45.314 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/ListPage-DlYXLXno.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 07:16:45.314 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:16:45.316 [reactor-http-epoll-2] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.104.143 - - [19/Aug/2026:07:16:45 +0000] "GET /assets/PlusIcon-ZsK0o-cX.js HTTP/1.1" 200 434 4
2026-08-19 07:16:45.317 [reactor-http-epoll-3] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.104.143 - - [19/Aug/2026:07:16:45 +0000] "GET /assets/Search-D1de03s6.js HTTP/1.1" 200 4374 11
2026-08-19 07:16:45.317 [reactor-http-epoll-3] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.104.143 - - [19/Aug/2026:07:16:45 +0000] "GET /assets/ActionButton-COAQ-YGZ.js HTTP/1.1" 200 665 9
2026-08-19 07:16:45.317 [reactor-http-epoll-3] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.104.143 - - [19/Aug/2026:07:16:45 +0000] "GET /assets/ListPage-DlYXLXno.js HTTP/1.1" 200 7065 6
2026-08-19 07:16:45.319 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/DownloadCsvButton-17ENBEk4.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 07:16:45.319 [reactor-http-epoll-2] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/ExportIcon-hB54pjUy.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 07:16:45.319 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:16:45.320 [reactor-http-epoll-2] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:16:45.325 [reactor-http-epoll-2] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.104.143 - - [19/Aug/2026:07:16:45 +0000] "GET /assets/ExportIcon-hB54pjUy.js HTTP/1.1" 200 898 6
2026-08-19 07:16:45.325 [reactor-http-epoll-3] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.104.143 - - [19/Aug/2026:07:16:45 +0000] "GET /assets/DownloadCsvButton-17ENBEk4.js HTTP/1.1" 200 700 6
2026-08-19 07:16:45.352 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/clusters/kafka-dev/topics' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@5b167194
2026-08-19 07:16:45.353 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:16:45.360 [reactor-http-epoll-2] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/clusters' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@5b167194
2026-08-19 07:16:45.360 [reactor-http-epoll-2] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:16:45.364 [reactor-http-epoll-2] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.104.143 - - [19/Aug/2026:07:16:45 +0000] "GET /api/clusters HTTP/1.1" 200 347 5
2026-08-19 07:16:45.687 [reactor-http-epoll-3] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.104.143 - - [19/Aug/2026:07:16:45 +0000] "GET /api/clusters/kafka-dev/topics?page=1&perPage=25&showInternal=true&fts=false HTTP/1.1" 200 12561 336
2026-08-19 07:16:48.444 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/clusters/kafka-dev/topics' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@5b167194
2026-08-19 07:16:48.445 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:16:48.771 [reactor-http-epoll-3] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.104.143 - - [19/Aug/2026:07:16:48 +0000] "GET /api/clusters/kafka-dev/topics?page=1&perPage=25&showInternal=true&search=Realtime.Payments.B2C.TEXT001.V1&fts=false HTTP/1.1" 200 724 330
2026-08-19 07:16:50.272 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/Topic-DRoA7Yr2.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 07:16:50.272 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:16:50.272 [reactor-http-epoll-2] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/utils-CH284mxw.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 07:16:50.272 [reactor-http-epoll-2] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:16:50.275 [reactor-http-epoll-2] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/EditorViewer-VrhowIkD.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 07:16:50.275 [reactor-http-epoll-2] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:16:50.275 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/fetch-IOhmRd8d.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 07:16:50.275 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:16:50.277 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/Table.styled-Bq0NrV6x.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 07:16:50.277 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:16:50.282 [reactor-http-epoll-3] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.104.143 - - [19/Aug/2026:07:16:50 +0000] "GET /assets/fetch-IOhmRd8d.js HTTP/1.1" 200 2478 7
2026-08-19 07:16:50.284 [reactor-http-epoll-3] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.104.143 - - [19/Aug/2026:07:16:50 +0000] "GET /assets/Topic-DRoA7Yr2.js HTTP/1.1" 200 529741 14
2026-08-19 07:16:50.285 [reactor-http-epoll-3] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.104.143 - - [19/Aug/2026:07:16:50 +0000] "GET /assets/Table.styled-Bq0NrV6x.js HTTP/1.1" 200 2936 9
2026-08-19 07:16:50.286 [reactor-http-epoll-2] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.104.143 - - [19/Aug/2026:07:16:50 +0000] "GET /assets/utils-CH284mxw.js HTTP/1.1" 200 7596 16
2026-08-19 07:16:50.287 [reactor-http-epoll-2] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/index-Cj7wsYkN.css' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 07:16:50.287 [reactor-http-epoll-2] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:16:50.289 [reactor-http-epoll-2] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.104.143 - - [19/Aug/2026:07:16:50 +0000] "GET /assets/EditorViewer-VrhowIkD.js HTTP/1.1" 200 10601 14
2026-08-19 07:16:50.289 [reactor-http-epoll-2] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.104.143 - - [19/Aug/2026:07:16:50 +0000] "GET /assets/index-Cj7wsYkN.css HTTP/1.1" 200 21912 10
2026-08-19 07:16:50.302 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/TableCells-fkcKFKS_.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 07:16:50.302 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:16:50.304 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/queryPersister-CkyJ1WEQ.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 07:16:50.304 [reactor-http-epoll-2] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/BreakableTextCell-DqvTDMqh.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 07:16:50.304 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:16:50.304 [reactor-http-epoll-2] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:16:50.306 [reactor-http-epoll-3] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.104.143 - - [19/Aug/2026:07:16:50 +0000] "GET /assets/TableCells-fkcKFKS_.js HTTP/1.1" 200 7966 4
2026-08-19 07:16:50.306 [reactor-http-epoll-3] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.104.143 - - [19/Aug/2026:07:16:50 +0000] "GET /assets/queryPersister-CkyJ1WEQ.js HTTP/1.1" 200 1159 2
2026-08-19 07:16:50.308 [reactor-http-epoll-2] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.104.143 - - [19/Aug/2026:07:16:50 +0000] "GET /assets/BreakableTextCell-DqvTDMqh.js HTTP/1.1" 200 161 4
2026-08-19 07:16:50.308 [reactor-http-epoll-2] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/consumers-Cs9Fl0rn.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 07:16:50.309 [reactor-http-epoll-2] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:16:50.310 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/TopicForm-pYLuj2DS.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 07:16:50.310 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:16:50.310 [reactor-http-epoll-2] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.104.143 - - [19/Aug/2026:07:16:50 +0000] "GET /assets/consumers-Cs9Fl0rn.js HTTP/1.1" 200 1947 2
2026-08-19 07:16:50.312 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/Form.styled-BOcoibvk.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 07:16:50.312 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:16:50.313 [reactor-http-epoll-2] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/index-N_7uqvWG.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 07:16:50.313 [reactor-http-epoll-2] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:16:50.314 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/ConnectorsTable-CArCXxZL.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 07:16:50.314 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:16:50.316 [reactor-http-epoll-3] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.104.143 - - [19/Aug/2026:07:16:50 +0000] "GET /assets/Form.styled-BOcoibvk.js HTTP/1.1" 200 419 4
2026-08-19 07:16:50.316 [reactor-http-epoll-3] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.104.143 - - [19/Aug/2026:07:16:50 +0000] "GET /assets/ConnectorsTable-CArCXxZL.js HTTP/1.1" 200 6855 3
2026-08-19 07:16:50.316 [reactor-http-epoll-2] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.104.143 - - [19/Aug/2026:07:16:50 +0000] "GET /assets/index-N_7uqvWG.js HTTP/1.1" 200 155211 3
2026-08-19 07:16:50.317 [reactor-http-epoll-3] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.104.143 - - [19/Aug/2026:07:16:50 +0000] "GET /assets/TopicForm-pYLuj2DS.js HTTP/1.1" 200 14107 8
2026-08-19 07:16:50.346 [reactor-http-epoll-2] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/clusters/kafka-dev/topics/Realtime.Payments.B2C.TEXT001.V1/connectors' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@5b167194
2026-08-19 07:16:50.347 [reactor-http-epoll-2] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:16:50.349 [reactor-http-epoll-2] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.104.143 - - [19/Aug/2026:07:16:50 +0000] "GET /api/clusters/kafka-dev/topics/Realtime.Payments.B2C.TEXT001.V1/connectors HTTP/1.1" 200 2 3
2026-08-19 07:16:50.359 [reactor-http-epoll-2] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/clusters/kafka-dev/topics/Realtime.Payments.B2C.TEXT001.V1/serdes' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@5b167194
2026-08-19 07:16:50.359 [reactor-http-epoll-2] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:16:50.361 [reactor-http-epoll-2] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.104.143 - - [19/Aug/2026:07:16:50 +0000] "GET /api/clusters/kafka-dev/topics/Realtime.Payments.B2C.TEXT001.V1/serdes?use=SERIALIZE HTTP/1.1" 200 2721 2
2026-08-19 07:16:50.413 [reactor-http-epoll-2] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/clusters/kafka-dev/topics/Realtime.Payments.B2C.TEXT001.V1' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@5b167194
2026-08-19 07:16:50.413 [reactor-http-epoll-2] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:16:50.669 [reactor-http-epoll-2] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.104.143 - - [19/Aug/2026:07:16:50 +0000] "GET /api/clusters/kafka-dev/topics/Realtime.Payments.B2C.TEXT001.V1 HTTP/1.1" 200 712 256
2026-08-19 07:16:50.688 [reactor-http-epoll-2] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/clusters/kafka-dev/topics/Realtime.Payments.B2C.TEXT001.V1' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@5b167194
2026-08-19 07:16:50.688 [reactor-http-epoll-2] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:16:50.939 [reactor-http-epoll-2] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.104.143 - - [19/Aug/2026:07:16:50 +0000] "GET /api/clusters/kafka-dev/topics/Realtime.Payments.B2C.TEXT001.V1 HTTP/1.1" 200 712 251
2026-08-19 07:16:53.322 [reactor-http-epoll-2] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/clusters/kafka-dev/topics/Realtime.Payments.B2C.TEXT001.V1/serdes' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@5b167194
2026-08-19 07:16:53.322 [reactor-http-epoll-2] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:16:53.326 [reactor-http-epoll-2] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.104.143 - - [19/Aug/2026:07:16:53 +0000] "GET /api/clusters/kafka-dev/topics/Realtime.Payments.B2C.TEXT001.V1/serdes?use=DESERIALIZE HTTP/1.1" 200 3937 5
2026-08-19 07:16:53.357 [reactor-http-epoll-2] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/clusters/kafka-dev/topics/Realtime.Payments.B2C.TEXT001.V1' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@5b167194
2026-08-19 07:16:53.357 [reactor-http-epoll-2] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:16:53.357 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/clusters/kafka-dev/topics/Realtime.Payments.B2C.TEXT001.V1/messages/v2' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@5b167194
2026-08-19 07:16:53.357 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:16:53.559 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/clusters/kafka-dev/topics/Realtime.Payments.B2C.TEXT001.V1/messages/v2' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@5b167194
2026-08-19 07:16:53.560 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:16:53.582 [boundedElastic-41] INFO  o.a.k.c.consumer.ConsumerConfig -  - - ConsumerConfig values: 
	allow.auto.create.topics = false
	auto.commit.interval.ms = 5000
	auto.include.jmx.reporter = true
	auto.offset.reset = earliest
	bootstrap.servers = [LINX102083TI1:9092]
	check.crcs = true
	client.dns.lookup = use_all_dns_ips
	client.id = kafbat-ui-consumer-1787123813573
	client.rack = 
	connections.max.idle.ms = 540000
	default.api.timeout.ms = 60000
	enable.auto.commit = false
	enable.metrics.push = true
	exclude.internal.topics = true
	fetch.max.bytes = 52428800
	fetch.max.wait.ms = 500
	fetch.min.bytes = 1
	group.id = null
	group.instance.id = null
	group.protocol = classic
	group.remote.assignor = null
	heartbeat.interval.ms = 3000
	interceptor.classes = []
	internal.leave.group.on.close = true
	internal.throw.on.fetch.stable.offset.unsupported = false
	isolation.level = read_uncommitted
	key.deserializer = class org.apache.kafka.common.serialization.BytesDeserializer
	max.partition.fetch.bytes = 1048576
	max.poll.interval.ms = 300000
	max.poll.records = 100
	metadata.max.age.ms = 300000
	metadata.recovery.strategy = none
	metric.reporters = []
	metrics.num.samples = 2
	metrics.recording.level = INFO
	metrics.sample.window.ms = 30000
	partition.assignment.strategy = [class org.apache.kafka.clients.consumer.RangeAssignor, class org.apache.kafka.clients.consumer.CooperativeStickyAssignor]
	receive.buffer.bytes = 65536
	reconnect.backoff.max.ms = 1000
	reconnect.backoff.ms = 50
	request.timeout.ms = 30000
	retry.backoff.max.ms = 1000
	retry.backoff.ms = 100
	sasl.client.callback.handler.class = null
	sasl.jaas.config = null
	sasl.kerberos.kinit.cmd = /usr/bin/kinit
	sasl.kerberos.min.time.before.relogin = 60000
	sasl.kerberos.service.name = null
	sasl.kerberos.ticket.renew.jitter = 0.05
	sasl.kerberos.ticket.renew.window.factor = 0.8
	sasl.login.callback.handler.class = null
	sasl.login.class = null
	sasl.login.connect.timeout.ms = null
	sasl.login.read.timeout.ms = null
	sasl.login.refresh.buffer.seconds = 300
	sasl.login.refresh.min.period.seconds = 60
	sasl.login.refresh.window.factor = 0.8
	sasl.login.refresh.window.jitter = 0.05
	sasl.login.retry.backoff.max.ms = 10000
	sasl.login.retry.backoff.ms = 100
	sasl.mechanism = GSSAPI
	sasl.oauthbearer.clock.skew.seconds = 30
	sasl.oauthbearer.expected.audience = null
	sasl.oauthbearer.expected.issuer = null
	sasl.oauthbearer.header.urlencode = false
	sasl.oauthbearer.jwks.endpoint.refresh.ms = 3600000
	sasl.oauthbearer.jwks.endpoint.retry.backoff.max.ms = 10000
	sasl.oauthbearer.jwks.endpoint.retry.backoff.ms = 100
	sasl.oauthbearer.jwks.endpoint.url = null
	sasl.oauthbearer.scope.claim.name = scope
	sasl.oauthbearer.sub.claim.name = sub
	sasl.oauthbearer.token.endpoint.url = null
	security.protocol = PLAINTEXT
	security.providers = null
	send.buffer.bytes = 131072
	session.timeout.ms = 45000
	socket.connection.setup.timeout.max.ms = 30000
	socket.connection.setup.timeout.ms = 10000
	ssl.cipher.suites = null
	ssl.enabled.protocols = [TLSv1.2, TLSv1.3]
	ssl.endpoint.identification.algorithm = https
	ssl.engine.factory.class = null
	ssl.key.password = null
	ssl.keymanager.algorithm = SunX509
	ssl.keystore.certificate.chain = null
	ssl.keystore.key = null
	ssl.keystore.location = null
	ssl.keystore.password = null
	ssl.keystore.type = JKS
	ssl.protocol = TLSv1.3
	ssl.provider = null
	ssl.secure.random.implementation = null
	ssl.trustmanager.algorithm = PKIX
	ssl.truststore.certificates = null
	ssl.truststore.location = null
	ssl.truststore.password = null
	ssl.truststore.type = JKS
	value.deserializer = class org.apache.kafka.common.serialization.BytesDeserializer

2026-08-19 07:16:53.601 [boundedElastic-41] INFO  o.a.k.c.t.i.KafkaMetricsCollector -  - - initializing Kafka metrics collector
2026-08-19 07:16:53.634 [boundedElastic-41] INFO  o.a.kafka.common.utils.AppInfoParser -  - - Kafka version: 7.9.5-ccs
2026-08-19 07:16:53.634 [boundedElastic-41] INFO  o.a.kafka.common.utils.AppInfoParser -  - - Kafka commitId: 4cbb817945d2251e
2026-08-19 07:16:53.635 [boundedElastic-41] INFO  o.a.kafka.common.utils.AppInfoParser -  - - Kafka startTimeMs: 1787123813634
2026-08-19 07:16:53.654 [boundedElastic-41] INFO  org.apache.kafka.clients.Metadata -  - - [Consumer clientId=kafbat-ui-consumer-1787123813573, groupId=null] Cluster ID: 7llUOb1oSwa4TMstH-TbNw
2026-08-19 07:16:53.685 [boundedElastic-41] INFO  o.a.k.c.c.i.ClassicKafkaConsumer -  - - [Consumer clientId=kafbat-ui-consumer-1787123813573, groupId=null] Assigned to partition(s): Realtime.Payments.B2C.TEXT001.V1-0
2026-08-19 07:16:53.689 [boundedElastic-41] INFO  o.a.k.c.c.i.ClassicKafkaConsumer -  - - [Consumer clientId=kafbat-ui-consumer-1787123813573, groupId=null] Seeking to offset 235 for partition Realtime.Payments.B2C.TEXT001.V1-0
2026-08-19 07:16:53.737 [reactor-http-epoll-2] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.104.143 - - [19/Aug/2026:07:16:53 +0000] "GET /api/clusters/kafka-dev/topics/Realtime.Payments.B2C.TEXT001.V1 HTTP/1.1" 200 712 381
2026-08-19 07:16:54.236 [boundedElastic-41] INFO  o.a.kafka.common.metrics.Metrics -  - - Metrics scheduler closed
2026-08-19 07:16:54.237 [boundedElastic-41] INFO  o.a.kafka.common.metrics.Metrics -  - - Closing reporter org.apache.kafka.common.metrics.JmxReporter
2026-08-19 07:16:54.237 [boundedElastic-41] INFO  o.a.kafka.common.metrics.Metrics -  - - Closing reporter org.apache.kafka.common.telemetry.internals.ClientTelemetryReporter
2026-08-19 07:16:54.237 [boundedElastic-41] INFO  o.a.kafka.common.metrics.Metrics -  - - Metrics reporters closed
2026-08-19 07:16:54.241 [boundedElastic-41] INFO  o.a.kafka.common.utils.AppInfoParser -  - - App info kafka.consumer for kafbat-ui-consumer-1787123813573 unregistered
2026-08-19 07:16:54.243 [reactor-http-epoll-3] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.104.143 - - [19/Aug/2026:07:16:53 +0000] "GET /api/clusters/kafka-dev/topics/Realtime.Payments.B2C.TEXT001.V1/messages/v2?limit=100&mode=LATEST HTTP/1.1" 200 54159 686
2026-08-19 07:17:32.531 [reactor-http-epoll-2] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/clusters' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@5b167194
2026-08-19 07:17:32.531 [reactor-http-epoll-2] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:17:32.531 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/info' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@5b167194
2026-08-19 07:17:32.531 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:17:32.534 [reactor-http-epoll-3] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.104.143 - - [19/Aug/2026:07:17:32 +0000] "GET /api/info HTTP/1.1" 200 205 5
2026-08-19 07:17:32.535 [reactor-http-epoll-2] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.104.143 - - [19/Aug/2026:07:17:32 +0000] "GET /api/clusters HTTP/1.1" 200 347 6
2026-08-19 07:17:32.535 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/clusters/kafka-dev/topics/Realtime.Payments.B2C.TEXT001.V1' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@5b167194
2026-08-19 07:17:32.535 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:17:32.535 [reactor-http-epoll-2] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/clusters/kafka-dev/topics/Realtime.Payments.B2C.TEXT001.V1/connectors' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@5b167194
2026-08-19 07:17:32.535 [reactor-http-epoll-2] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:17:32.537 [reactor-http-epoll-2] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.104.143 - - [19/Aug/2026:07:17:32 +0000] "GET /api/clusters/kafka-dev/topics/Realtime.Payments.B2C.TEXT001.V1/connectors HTTP/1.1" 200 2 2
2026-08-19 07:17:32.840 [reactor-http-epoll-3] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.104.143 - - [19/Aug/2026:07:17:32 +0000] "GET /api/clusters/kafka-dev/topics/Realtime.Payments.B2C.TEXT001.V1 HTTP/1.1" 200 712 306
2026-08-19 07:18:04.909 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/info' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@5b167194
2026-08-19 07:18:04.909 [reactor-http-epoll-2] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/clusters' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@5b167194
2026-08-19 07:18:04.910 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:18:04.910 [reactor-http-epoll-2] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:18:04.913 [reactor-http-epoll-3] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.104.143 - - [19/Aug/2026:07:18:04 +0000] "GET /api/info HTTP/1.1" 200 205 6
2026-08-19 07:18:04.914 [reactor-http-epoll-2] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.104.143 - - [19/Aug/2026:07:18:04 +0000] "GET /api/clusters HTTP/1.1" 200 347 7
2026-08-19 07:18:04.914 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/clusters/kafka-dev/topics/Realtime.Payments.B2C.TEXT001.V1/connectors' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@5b167194
2026-08-19 07:18:04.915 [reactor-http-epoll-2] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/clusters/kafka-dev/topics/Realtime.Payments.B2C.TEXT001.V1' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@5b167194
2026-08-19 07:18:04.915 [reactor-http-epoll-2] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:18:04.915 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:18:04.917 [reactor-http-epoll-3] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.104.143 - - [19/Aug/2026:07:18:04 +0000] "GET /api/clusters/kafka-dev/topics/Realtime.Payments.B2C.TEXT001.V1/connectors HTTP/1.1" 200 2 3
2026-08-19 07:18:05.225 [reactor-http-epoll-2] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.104.143 - - [19/Aug/2026:07:18:04 +0000] "GET /api/clusters/kafka-dev/topics/Realtime.Payments.B2C.TEXT001.V1 HTTP/1.1" 200 712 311
2026-08-19 07:20:05.177 [reactor-http-epoll-2] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/info' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@5b167194
2026-08-19 07:20:05.177 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/clusters' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@5b167194
2026-08-19 07:20:05.177 [reactor-http-epoll-2] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:20:05.177 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:20:05.181 [reactor-http-epoll-2] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.104.143 - - [19/Aug/2026:07:20:05 +0000] "GET /api/info HTTP/1.1" 200 205 7
2026-08-19 07:20:05.181 [reactor-http-epoll-3] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.104.143 - - [19/Aug/2026:07:20:05 +0000] "GET /api/clusters HTTP/1.1" 200 347 7
2026-08-19 07:20:05.182 [reactor-http-epoll-2] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/clusters/kafka-dev/topics/Realtime.Payments.B2C.TEXT001.V1/connectors' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@5b167194
2026-08-19 07:20:05.182 [reactor-http-epoll-2] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:20:05.182 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/clusters/kafka-dev/topics/Realtime.Payments.B2C.TEXT001.V1' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@5b167194
2026-08-19 07:20:05.182 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:20:05.183 [reactor-http-epoll-2] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.104.143 - - [19/Aug/2026:07:20:05 +0000] "GET /api/clusters/kafka-dev/topics/Realtime.Payments.B2C.TEXT001.V1/connectors HTTP/1.1" 200 2 2
2026-08-19 07:20:05.450 [reactor-http-epoll-3] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.104.143 - - [19/Aug/2026:07:20:05 +0000] "GET /api/clusters/kafka-dev/topics/Realtime.Payments.B2C.TEXT001.V1 HTTP/1.1" 200 712 269
2026-08-19 07:21:15.373 [parallel-3] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/info' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@5b167194
2026-08-19 07:21:15.374 [parallel-3] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization failed: Access Denied
2026-08-19 07:21:15.374 [parallel-4] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/clusters' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@5b167194
2026-08-19 07:21:15.375 [parallel-4] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization failed: Access Denied
2026-08-19 07:21:15.376 [reactor-http-epoll-3] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.100.208 - - [19/Aug/2026:07:21:15 +0000] "GET /api/info HTTP/1.1" 302 0 5
2026-08-19 07:21:15.376 [reactor-http-epoll-4] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.100.208 - - [19/Aug/2026:07:21:15 +0000] "GET /api/clusters HTTP/1.1" 302 0 2
2026-08-19 07:21:15.383 [reactor-http-epoll-4] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.100.208 - - [19/Aug/2026:07:21:15 +0000] "GET /login HTTP/1.1" 200 1816 0
2026-08-19 07:21:15.392 [reactor-http-epoll-4] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.100.208 - - [19/Aug/2026:07:21:15 +0000] "GET /login HTTP/1.1" 200 1816 1
2026-08-19 07:21:17.581 [parallel-1] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@5b167194
2026-08-19 07:21:17.581 [parallel-1] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization failed: Access Denied
2026-08-19 07:21:17.582 [reactor-http-epoll-4] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.100.208 - - [19/Aug/2026:07:21:17 +0000] "GET / HTTP/1.1" 302 0 2
2026-08-19 07:21:17.591 [reactor-http-epoll-4] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.100.208 - - [19/Aug/2026:07:21:17 +0000] "GET /login HTTP/1.1" 200 1816 1
2026-08-19 07:21:17.649 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/index-ToFdRV4e.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 07:21:17.650 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:21:17.652 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/@react-router-D-4KBoK_.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 07:21:17.652 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:21:17.656 [reactor-http-epoll-3] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.100.208 - - [19/Aug/2026:07:21:17 +0000] "GET /assets/@react-router-D-4KBoK_.js HTTP/1.1" 200 166169 5
2026-08-19 07:21:17.669 [reactor-http-epoll-4] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.100.208 - - [19/Aug/2026:07:21:17 +0000] "GET /assets/index-ToFdRV4e.js HTTP/1.1" 200 344993 20
2026-08-19 07:21:17.678 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/index-D3Fzj2d9.css' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 07:21:17.678 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:21:17.680 [reactor-http-epoll-3] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.100.208 - - [19/Aug/2026:07:21:17 +0000] "GET /assets/index-D3Fzj2d9.css HTTP/1.1" 200 1617 3
2026-08-19 07:21:17.991 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/AuthPage-DYy823dD.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 07:21:17.992 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:21:17.993 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/AlertIcon-CaXsK92Y.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 07:21:17.993 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:21:17.996 [reactor-http-epoll-4] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.100.208 - - [19/Aug/2026:07:21:17 +0000] "GET /assets/AlertIcon-CaXsK92Y.js HTTP/1.1" 200 684 4
2026-08-19 07:21:17.999 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/favicon/favicon.svg' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 07:21:18.000 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:21:18.001 [reactor-http-epoll-4] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.100.208 - - [19/Aug/2026:07:21:17 +0000] "GET /favicon/favicon.svg HTTP/1.1" 200 712 2
2026-08-19 07:21:18.002 [reactor-http-epoll-3] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.100.208 - - [19/Aug/2026:07:21:17 +0000] "GET /assets/AuthPage-DYy823dD.js HTTP/1.1" 200 23430 12
2026-08-19 07:21:18.099 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/config/authentication' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 07:21:18.099 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:21:18.101 [reactor-http-epoll-3] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.100.208 - - [19/Aug/2026:07:21:18 +0000] "GET /api/config/authentication HTTP/1.1" 200 39 3
2026-08-19 07:21:18.149 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/fonts/Inter-Medium.ttf' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 07:21:18.150 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:21:18.151 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/fonts/Inter-Regular.ttf' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 07:21:18.151 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:21:18.189 [reactor-http-epoll-3] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.100.208 - - [19/Aug/2026:07:21:18 +0000] "GET /fonts/Inter-Medium.ttf HTTP/1.1" 200 308392 40
2026-08-19 07:21:18.198 [reactor-http-epoll-4] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.100.208 - - [19/Aug/2026:07:21:18 +0000] "GET /fonts/Inter-Regular.ttf HTTP/1.1" 200 303504 47
2026-08-19 07:21:58.670 [reactor-http-epoll-4] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.100.208 - - [19/Aug/2026:07:21:57 +0000] "POST /login HTTP/1.1" 302 0 818
2026-08-19 07:21:58.678 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@5b167194
2026-08-19 07:21:58.679 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:21:58.681 [reactor-http-epoll-4] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.100.208 - - [19/Aug/2026:07:21:58 +0000] "GET / HTTP/1.1" 200 1816 4
2026-08-19 07:21:58.708 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/info' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@5b167194
2026-08-19 07:21:58.708 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:21:58.709 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/clusters/kafka-dev/topics/bll.ems.mesarim.salaryCredit.pepper.t' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@5b167194
2026-08-19 07:21:58.709 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:21:58.710 [reactor-http-epoll-1] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/clusters' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@5b167194
2026-08-19 07:21:58.710 [reactor-http-epoll-1] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:21:58.711 [reactor-http-epoll-2] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/clusters/kafka-dev/topics/bll.ems.mesarim.salaryCredit.pepper.t/connectors' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@5b167194
2026-08-19 07:21:58.712 [reactor-http-epoll-2] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:21:58.712 [reactor-http-epoll-4] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.101.177 - - [19/Aug/2026:07:21:58 +0000] "GET /api/info HTTP/1.1" 200 205 5
2026-08-19 07:21:58.713 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/info' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@5b167194
2026-08-19 07:21:58.713 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:21:58.713 [reactor-http-epoll-1] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.101.177 - - [19/Aug/2026:07:21:58 +0000] "GET /api/clusters HTTP/1.1" 200 347 6
2026-08-19 07:21:58.714 [reactor-http-epoll-4] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.100.208 - - [19/Aug/2026:07:21:58 +0000] "GET /api/info HTTP/1.1" 200 205 2
2026-08-19 07:21:58.714 [reactor-http-epoll-2] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.101.177 - - [19/Aug/2026:07:21:58 +0000] "GET /api/clusters/kafka-dev/topics/bll.ems.mesarim.salaryCredit.pepper.t/connectors HTTP/1.1" 200 2 4
2026-08-19 07:21:58.773 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/authorization' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 07:21:58.773 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:21:58.774 [reactor-http-epoll-4] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.100.208 - - [19/Aug/2026:07:21:58 +0000] "GET /api/authorization HTTP/1.1" 200 71 2
2026-08-19 07:21:58.846 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/info' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@5b167194
2026-08-19 07:21:58.846 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:21:58.848 [reactor-http-epoll-4] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.100.208 - - [19/Aug/2026:07:21:58 +0000] "GET /api/info HTTP/1.1" 200 205 3
2026-08-19 07:21:58.875 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/ActionComponent.styled-CtMfGuhc.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 07:21:58.875 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:21:58.876 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/Dashboard-949avtj_.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 07:21:58.876 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:21:58.879 [reactor-http-epoll-4] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.100.208 - - [19/Aug/2026:07:21:58 +0000] "GET /assets/Dashboard-949avtj_.js HTTP/1.1" 200 3137 4
2026-08-19 07:21:58.883 [reactor-http-epoll-3] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.100.208 - - [19/Aug/2026:07:21:58 +0000] "GET /assets/ActionComponent.styled-CtMfGuhc.js HTTP/1.1" 200 119533 8
2026-08-19 07:21:58.890 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/Heading.styled-DGSlQalk.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 07:21:58.890 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:21:58.892 [reactor-http-epoll-4] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.100.208 - - [19/Aug/2026:07:21:58 +0000] "GET /assets/Heading.styled-DGSlQalk.js HTTP/1.1" 200 285 3
2026-08-19 07:21:58.892 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/SizeCell-C-hVT6uc.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 07:21:58.893 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:21:58.902 [reactor-http-epoll-3] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.100.208 - - [19/Aug/2026:07:21:58 +0000] "GET /assets/SizeCell-C-hVT6uc.js HTTP/1.1" 200 176 11
2026-08-19 07:21:58.903 [reactor-http-epoll-1] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/BytesFormatted-QhqsAXvV.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 07:21:58.904 [reactor-http-epoll-1] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:21:58.906 [reactor-http-epoll-1] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.100.208 - - [19/Aug/2026:07:21:58 +0000] "GET /assets/BytesFormatted-QhqsAXvV.js HTTP/1.1" 200 591 3
2026-08-19 07:21:58.907 [reactor-http-epoll-2] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/localStoragePersister-D-viOm25.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 07:21:58.907 [reactor-http-epoll-2] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:21:58.909 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/ActionCanButton-BCx801KA.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 07:21:58.909 [reactor-http-epoll-2] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.100.208 - - [19/Aug/2026:07:21:58 +0000] "GET /assets/localStoragePersister-D-viOm25.js HTTP/1.1" 200 590 3
2026-08-19 07:21:58.909 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:21:58.911 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/Switch-DR0XBu1-.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000035838688@599052fd
2026-08-19 07:21:58.911 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:21:58.911 [reactor-http-epoll-3] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.100.208 - - [19/Aug/2026:07:21:58 +0000] "GET /assets/ActionCanButton-BCx801KA.js HTTP/1.1" 200 456 3
2026-08-19 07:21:58.912 [reactor-http-epoll-4] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.100.208 - - [19/Aug/2026:07:21:58 +0000] "GET /assets/Switch-DR0XBu1-.js HTTP/1.1" 200 1130 2
2026-08-19 07:21:58.982 [reactor-http-epoll-3] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.101.177 - - [19/Aug/2026:07:21:58 +0000] "GET /api/clusters/kafka-dev/topics/bll.ems.mesarim.salaryCredit.pepper.t HTTP/1.1" 200 518 273
2026-08-19 07:21:59.038 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/clusters' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@5b167194
2026-08-19 07:21:59.038 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:21:59.041 [reactor-http-epoll-4] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.100.208 - - [19/Aug/2026:07:21:59 +0000] "GET /api/clusters HTTP/1.1" 200 2 4
2026-08-19 07:22:05.175 [reactor-http-epoll-2] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/clusters' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@5b167194
2026-08-19 07:22:05.175 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/info' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@5b167194
2026-08-19 07:22:05.175 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:22:05.175 [reactor-http-epoll-2] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:22:05.177 [reactor-http-epoll-3] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.104.143 - - [19/Aug/2026:07:22:05 +0000] "GET /api/info HTTP/1.1" 200 205 2
2026-08-19 07:22:05.178 [reactor-http-epoll-2] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.104.143 - - [19/Aug/2026:07:22:05 +0000] "GET /api/clusters HTTP/1.1" 200 347 4
2026-08-19 07:22:05.178 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/clusters/kafka-dev/topics/Realtime.Payments.B2C.TEXT001.V1' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@5b167194
2026-08-19 07:22:05.178 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:22:05.178 [reactor-http-epoll-2] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/clusters/kafka-dev/topics/Realtime.Payments.B2C.TEXT001.V1/connectors' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@5b167194
2026-08-19 07:22:05.178 [reactor-http-epoll-2] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:22:05.180 [reactor-http-epoll-2] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.104.143 - - [19/Aug/2026:07:22:05 +0000] "GET /api/clusters/kafka-dev/topics/Realtime.Payments.B2C.TEXT001.V1/connectors HTTP/1.1" 200 2 2
2026-08-19 07:22:05.435 [reactor-http-epoll-3] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.104.143 - - [19/Aug/2026:07:22:05 +0000] "GET /api/clusters/kafka-dev/topics/Realtime.Payments.B2C.TEXT001.V1 HTTP/1.1" 200 712 258
2026-08-19 07:22:10.908 [reactor-http-epoll-2] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/clusters' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@5b167194
2026-08-19 07:22:10.908 [reactor-http-epoll-1] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/info' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@5b167194
2026-08-19 07:22:10.909 [reactor-http-epoll-2] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:22:10.909 [reactor-http-epoll-1] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:22:10.910 [reactor-http-epoll-1] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.109.47 - - [19/Aug/2026:07:22:10 +0000] "GET /api/info HTTP/1.1" 200 205 2
2026-08-19 07:22:10.911 [reactor-http-epoll-2] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.109.47 - - [19/Aug/2026:07:22:10 +0000] "GET /api/clusters HTTP/1.1" 200 2 3
2026-08-19 07:23:49.278 [reactor-http-epoll-1] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/clusters/kafka-dev/topics/bll.ems.mesarim.salaryCredit.pepper.t' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@5b167194
2026-08-19 07:23:49.279 [reactor-http-epoll-1] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:23:49.278 [reactor-http-epoll-2] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/clusters' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@5b167194
2026-08-19 07:23:49.278 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/info' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@5b167194
2026-08-19 07:23:49.281 [reactor-http-epoll-2] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:23:49.281 [reactor-http-epoll-3] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:23:49.278 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/clusters/kafka-dev/topics/bll.ems.mesarim.salaryCredit.pepper.t/connectors' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@5b167194
2026-08-19 07:23:49.281 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:23:49.283 [reactor-http-epoll-3] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.101.177 - - [19/Aug/2026:07:23:49 +0000] "GET /api/info HTTP/1.1" 200 205 7
2026-08-19 07:23:49.284 [reactor-http-epoll-4] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.101.177 - - [19/Aug/2026:07:23:49 +0000] "GET /api/clusters/kafka-dev/topics/bll.ems.mesarim.salaryCredit.pepper.t/connectors HTTP/1.1" 200 2 6
2026-08-19 07:23:49.286 [reactor-http-epoll-2] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.101.177 - - [19/Aug/2026:07:23:49 +0000] "GET /api/clusters HTTP/1.1" 200 347 9
2026-08-19 07:23:49.543 [reactor-http-epoll-1] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.101.177 - - [19/Aug/2026:07:23:49 +0000] "GET /api/clusters/kafka-dev/topics/bll.ems.mesarim.salaryCredit.pepper.t HTTP/1.1" 200 518 267
2026-08-19 07:24:28.059 [SpringApplicationShutdownHook] INFO  o.s.b.w.e.netty.GracefulShutdown -  - - Commencing graceful shutdown. Waiting for active requests to complete
2026-08-19 07:24:28.064 [netty-shutdown] INFO  o.s.b.w.e.netty.GracefulShutdown -  - - Graceful shutdown complete
2026-08-19 07:24:30.082 [kafka-admin-client-thread | kafbat-ui-admin-1787050304-1] INFO  o.a.kafka.common.utils.AppInfoParser -  - - App info kafka.admin.client for kafbat-ui-admin-1787050304-1 unregistered
2026-08-19 07:24:30.083 [kafka-admin-client-thread | kafbat-ui-admin-1787050304-1] INFO  o.a.kafka.common.metrics.Metrics -  - - Metrics scheduler closed
2026-08-19 07:24:30.083 [kafka-admin-client-thread | kafbat-ui-admin-1787050304-1] INFO  o.a.kafka.common.metrics.Metrics -  - - Closing reporter org.apache.kafka.common.metrics.JmxReporter
2026-08-19 07:24:30.083 [kafka-admin-client-thread | kafbat-ui-admin-1787050304-1] INFO  o.a.kafka.common.metrics.Metrics -  - - Metrics reporters closed
2026-08-19 07:24:31.990 [background-preinit] INFO  o.h.validator.internal.util.Version -  - - HV000001: Hibernate Validator 8.0.3.Final
2026-08-19 07:24:32.079 [main] INFO  io.kafbat.ui.KafkaUiApplication -  - - Starting KafkaUiApplication vv1.5.0 using Java 25.0.2 with PID 1 (/api.jar started by kafkaui in /)
2026-08-19 07:24:32.080 [main] INFO  io.kafbat.ui.KafkaUiApplication -  - - No active profile set, falling back to 1 default profile: "default"
2026-08-19 07:24:36.184 [main] INFO  o.s.b.a.e.web.EndpointLinksResolver -  - - Exposing 1 endpoint beneath base path '/actuator'
2026-08-19 07:24:36.346 [main] INFO  i.k.u.config.auth.LdapSecurityConfig -  - - Configuring LDAP authentication.
2026-08-19 07:24:36.871 [main] INFO  o.s.b.w.e.netty.NettyWebServer -  - - Netty started on port 8444 (https)
2026-08-19 07:24:36.887 [main] INFO  io.kafbat.ui.KafkaUiApplication -  - - Started KafkaUiApplication in 5.578 seconds (process running for 6.18)
2026-08-19 07:24:37.059 [boundedElastic-1] INFO  o.a.k.c.admin.AdminClientConfig -  - - AdminClientConfig values: 
	auto.include.jmx.reporter = true
	bootstrap.controllers = []
	bootstrap.servers = [LINX102083TI1:9092]
	client.dns.lookup = use_all_dns_ips
	client.id = kafbat-ui-admin-1787124277-1
	connections.max.idle.ms = 300000
	default.api.timeout.ms = 60000
	enable.metrics.push = true
	metadata.max.age.ms = 300000
	metadata.recovery.strategy = none
	metric.reporters = []
	metrics.num.samples = 2
	metrics.recording.level = INFO
	metrics.sample.window.ms = 30000
	receive.buffer.bytes = 65536
	reconnect.backoff.max.ms = 1000
	reconnect.backoff.ms = 50
	request.timeout.ms = 30000
	retries = 2147483647
	retry.backoff.max.ms = 1000
	retry.backoff.ms = 100
	sasl.client.callback.handler.class = null
	sasl.jaas.config = null
	sasl.kerberos.kinit.cmd = /usr/bin/kinit
	sasl.kerberos.min.time.before.relogin = 60000
	sasl.kerberos.service.name = null
	sasl.kerberos.ticket.renew.jitter = 0.05
	sasl.kerberos.ticket.renew.window.factor = 0.8
	sasl.login.callback.handler.class = null
	sasl.login.class = null
	sasl.login.connect.timeout.ms = null
	sasl.login.read.timeout.ms = null
	sasl.login.refresh.buffer.seconds = 300
	sasl.login.refresh.min.period.seconds = 60
	sasl.login.refresh.window.factor = 0.8
	sasl.login.refresh.window.jitter = 0.05
	sasl.login.retry.backoff.max.ms = 10000
	sasl.login.retry.backoff.ms = 100
	sasl.mechanism = GSSAPI
	sasl.oauthbearer.clock.skew.seconds = 30
	sasl.oauthbearer.expected.audience = null
	sasl.oauthbearer.expected.issuer = null
	sasl.oauthbearer.header.urlencode = false
	sasl.oauthbearer.jwks.endpoint.refresh.ms = 3600000
	sasl.oauthbearer.jwks.endpoint.retry.backoff.max.ms = 10000
	sasl.oauthbearer.jwks.endpoint.retry.backoff.ms = 100
	sasl.oauthbearer.jwks.endpoint.url = null
	sasl.oauthbearer.scope.claim.name = scope
	sasl.oauthbearer.sub.claim.name = sub
	sasl.oauthbearer.token.endpoint.url = null
	security.protocol = PLAINTEXT
	security.providers = null
	send.buffer.bytes = 131072
	socket.connection.setup.timeout.max.ms = 30000
	socket.connection.setup.timeout.ms = 10000
	ssl.cipher.suites = null
	ssl.enabled.protocols = [TLSv1.2, TLSv1.3]
	ssl.endpoint.identification.algorithm = https
	ssl.engine.factory.class = null
	ssl.key.password = null
	ssl.keymanager.algorithm = SunX509
	ssl.keystore.certificate.chain = null
	ssl.keystore.key = null
	ssl.keystore.location = null
	ssl.keystore.password = null
	ssl.keystore.type = JKS
	ssl.protocol = TLSv1.3
	ssl.provider = null
	ssl.secure.random.implementation = null
	ssl.trustmanager.algorithm = PKIX
	ssl.truststore.certificates = null
	ssl.truststore.location = null
	ssl.truststore.password = null
	ssl.truststore.type = JKS

2026-08-19 07:24:37.130 [boundedElastic-1] INFO  o.a.kafka.common.utils.AppInfoParser -  - - Kafka version: 7.9.5-ccs
2026-08-19 07:24:37.130 [boundedElastic-1] INFO  o.a.kafka.common.utils.AppInfoParser -  - - Kafka commitId: 4cbb817945d2251e
2026-08-19 07:24:37.130 [boundedElastic-1] INFO  o.a.kafka.common.utils.AppInfoParser -  - - Kafka startTimeMs: 1787124277129
2026-08-19 07:24:42.681 [parallel-2] WARN  o.a.l.i.v.VectorizationProvider -  - - Java vector incubator module is not readable. For optimal vector performance, pass '--add-modules jdk.incubator.vector' to enable Vector API.
2026-08-19 07:24:51.057 [parallel-3] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@296a887b
2026-08-19 07:24:51.060 [parallel-3] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization failed: Access Denied
2026-08-19 07:24:51.093 [reactor-http-epoll-1] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.98.81 - - [19/Aug/2026:07:24:51 +0000] "GET / HTTP/1.1" 302 0 92
2026-08-19 07:24:51.110 [reactor-http-epoll-1] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.98.81 - - [19/Aug/2026:07:24:51 +0000] "GET /login HTTP/1.1" 200 1816 13
2026-08-19 07:24:51.139 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/@react-router-D-4KBoK_.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000057838230@643fac44
2026-08-19 07:24:51.139 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:24:51.140 [reactor-http-epoll-1] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/index-ToFdRV4e.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000057838230@643fac44
2026-08-19 07:24:51.141 [reactor-http-epoll-1] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:24:51.202 [reactor-http-epoll-2] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/index-D3Fzj2d9.css' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000057838230@643fac44
2026-08-19 07:24:51.202 [reactor-http-epoll-2] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:24:51.215 [reactor-http-epoll-2] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.98.81 - - [19/Aug/2026:07:24:51 +0000] "GET /assets/index-D3Fzj2d9.css HTTP/1.1" 200 1617 15
2026-08-19 07:24:51.231 [reactor-http-epoll-1] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.98.81 - - [19/Aug/2026:07:24:51 +0000] "GET /assets/index-ToFdRV4e.js HTTP/1.1" 200 344993 96
2026-08-19 07:24:51.232 [reactor-http-epoll-4] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.98.81 - - [19/Aug/2026:07:24:51 +0000] "GET /assets/@react-router-D-4KBoK_.js HTTP/1.1" 200 166169 93
2026-08-19 07:24:51.377 [reactor-http-epoll-1] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/AuthPage-DYy823dD.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000057838230@643fac44
2026-08-19 07:24:51.378 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/AlertIcon-CaXsK92Y.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000057838230@643fac44
2026-08-19 07:24:51.378 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:24:51.379 [reactor-http-epoll-1] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:24:51.383 [reactor-http-epoll-4] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.98.81 - - [19/Aug/2026:07:24:51 +0000] "GET /assets/AlertIcon-CaXsK92Y.js HTTP/1.1" 200 684 6
2026-08-19 07:24:51.384 [reactor-http-epoll-1] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.98.81 - - [19/Aug/2026:07:24:51 +0000] "GET /assets/AuthPage-DYy823dD.js HTTP/1.1" 200 23430 9
2026-08-19 07:24:51.403 [reactor-http-epoll-1] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/config/authentication' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000057838230@643fac44
2026-08-19 07:24:51.403 [reactor-http-epoll-1] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:24:51.428 [parallel-4] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/manifest.json' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000057838230@643fac44
2026-08-19 07:24:51.429 [parallel-4] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:24:51.439 [reactor-http-epoll-3] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.98.81 - - [19/Aug/2026:07:24:51 +0000] "GET /manifest.json HTTP/1.1" 200 249 15
2026-08-19 07:24:51.493 [reactor-http-epoll-1] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.98.81 - - [19/Aug/2026:07:24:51 +0000] "GET /api/config/authentication HTTP/1.1" 200 39 92
2026-08-19 07:24:51.532 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/fonts/Inter-Regular.ttf' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000057838230@643fac44
2026-08-19 07:24:51.533 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:24:51.540 [reactor-http-epoll-1] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/fonts/Inter-Medium.ttf' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000057838230@643fac44
2026-08-19 07:24:51.542 [reactor-http-epoll-1] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:24:51.548 [reactor-http-epoll-4] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.98.81 - - [19/Aug/2026:07:24:51 +0000] "GET /fonts/Inter-Regular.ttf HTTP/1.1" 200 303504 18
2026-08-19 07:24:51.558 [reactor-http-epoll-1] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.98.81 - - [19/Aug/2026:07:24:51 +0000] "GET /fonts/Inter-Medium.ttf HTTP/1.1" 200 308392 22
2026-08-19 07:25:06.535 [reactor-http-epoll-1] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.98.81 - - [19/Aug/2026:07:25:05 +0000] "POST /login HTTP/1.1" 302 0 1219
2026-08-19 07:25:06.543 [reactor-http-epoll-1] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@296a887b
2026-08-19 07:25:06.544 [reactor-http-epoll-1] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:25:06.550 [reactor-http-epoll-1] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.98.81 - - [19/Aug/2026:07:25:06 +0000] "GET / HTTP/1.1" 200 1816 10
2026-08-19 07:25:06.612 [reactor-http-epoll-1] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/info' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@296a887b
2026-08-19 07:25:06.612 [reactor-http-epoll-1] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:25:06.620 [reactor-http-epoll-1] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.98.81 - - [19/Aug/2026:07:25:06 +0000] "GET /api/info HTTP/1.1" 200 205 10
2026-08-19 07:25:06.632 [reactor-http-epoll-1] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/authorization' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000057838230@643fac44
2026-08-19 07:25:06.633 [reactor-http-epoll-1] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:25:06.647 [reactor-http-epoll-1] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.98.81 - - [19/Aug/2026:07:25:06 +0000] "GET /api/authorization HTTP/1.1" 200 894 16
2026-08-19 07:25:06.668 [reactor-http-epoll-1] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/info' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@296a887b
2026-08-19 07:25:06.669 [reactor-http-epoll-1] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:25:06.671 [reactor-http-epoll-1] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.98.81 - - [19/Aug/2026:07:25:06 +0000] "GET /api/info HTTP/1.1" 200 205 4
2026-08-19 07:25:06.688 [reactor-http-epoll-1] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/Dashboard-949avtj_.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000057838230@643fac44
2026-08-19 07:25:06.689 [reactor-http-epoll-1] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:25:06.690 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/ActionComponent.styled-CtMfGuhc.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000057838230@643fac44
2026-08-19 07:25:06.690 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:25:06.691 [reactor-http-epoll-2] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/Heading.styled-DGSlQalk.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000057838230@643fac44
2026-08-19 07:25:06.692 [reactor-http-epoll-2] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:25:06.696 [reactor-http-epoll-2] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.98.81 - - [19/Aug/2026:07:25:06 +0000] "GET /assets/Heading.styled-DGSlQalk.js HTTP/1.1" 200 285 6
2026-08-19 07:25:06.704 [reactor-http-epoll-4] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.98.81 - - [19/Aug/2026:07:25:06 +0000] "GET /assets/ActionComponent.styled-CtMfGuhc.js HTTP/1.1" 200 119533 15
2026-08-19 07:25:06.708 [reactor-http-epoll-1] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.98.81 - - [19/Aug/2026:07:25:06 +0000] "GET /assets/Dashboard-949avtj_.js HTTP/1.1" 200 3137 21
2026-08-19 07:25:06.709 [reactor-http-epoll-2] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/Switch-DR0XBu1-.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000057838230@643fac44
2026-08-19 07:25:06.709 [reactor-http-epoll-2] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:25:06.710 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/SizeCell-C-hVT6uc.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000057838230@643fac44
2026-08-19 07:25:06.710 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:25:06.712 [reactor-http-epoll-1] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/ActionCanButton-BCx801KA.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000057838230@643fac44
2026-08-19 07:25:06.713 [reactor-http-epoll-1] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:25:06.714 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/BytesFormatted-QhqsAXvV.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000057838230@643fac44
2026-08-19 07:25:06.715 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:25:06.717 [reactor-http-epoll-2] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.98.81 - - [19/Aug/2026:07:25:06 +0000] "GET /assets/Switch-DR0XBu1-.js HTTP/1.1" 200 1130 9
2026-08-19 07:25:06.718 [reactor-http-epoll-4] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.98.81 - - [19/Aug/2026:07:25:06 +0000] "GET /assets/SizeCell-C-hVT6uc.js HTTP/1.1" 200 176 9
2026-08-19 07:25:06.719 [reactor-http-epoll-4] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.98.81 - - [19/Aug/2026:07:25:06 +0000] "GET /assets/BytesFormatted-QhqsAXvV.js HTTP/1.1" 200 591 6
2026-08-19 07:25:06.720 [reactor-http-epoll-1] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.98.81 - - [19/Aug/2026:07:25:06 +0000] "GET /assets/ActionCanButton-BCx801KA.js HTTP/1.1" 200 456 9
2026-08-19 07:25:06.724 [reactor-http-epoll-1] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/localStoragePersister-D-viOm25.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000057838230@643fac44
2026-08-19 07:25:06.724 [reactor-http-epoll-1] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:25:06.727 [reactor-http-epoll-1] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.98.81 - - [19/Aug/2026:07:25:06 +0000] "GET /assets/localStoragePersister-D-viOm25.js HTTP/1.1" 200 590 5
2026-08-19 07:25:06.768 [reactor-http-epoll-1] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/clusters' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@296a887b
2026-08-19 07:25:06.768 [reactor-http-epoll-1] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:25:06.795 [reactor-http-epoll-1] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.98.81 - - [19/Aug/2026:07:25:06 +0000] "GET /api/clusters HTTP/1.1" 200 347 29
2026-08-19 07:25:11.539 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/ace-Bj5lQZzX.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000057838230@643fac44
2026-08-19 07:25:11.539 [reactor-http-epoll-1] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/ClusterPage-gx6pMY3q.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000057838230@643fac44
2026-08-19 07:25:11.539 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:25:11.539 [reactor-http-epoll-1] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:25:11.544 [reactor-http-epoll-1] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/index.esm-BgXUD10i.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000057838230@643fac44
2026-08-19 07:25:11.544 [reactor-http-epoll-1] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:25:11.640 [reactor-http-epoll-1] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.98.81 - - [19/Aug/2026:07:25:11 +0000] "GET /assets/ClusterPage-gx6pMY3q.js HTTP/1.1" 200 32435 104
2026-08-19 07:25:11.643 [reactor-http-epoll-1] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.98.81 - - [19/Aug/2026:07:25:11 +0000] "GET /assets/index.esm-BgXUD10i.js HTTP/1.1" 200 45613 100
2026-08-19 07:25:11.654 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/ErrorPage-D3l2PA1n.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000057838230@643fac44
2026-08-19 07:25:11.655 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:25:11.722 [reactor-http-epoll-4] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.98.81 - - [19/Aug/2026:07:25:11 +0000] "GET /assets/ErrorPage-D3l2PA1n.js HTTP/1.1" 200 1352648 69
2026-08-19 07:25:11.725 [reactor-http-epoll-4] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.98.81 - - [19/Aug/2026:07:25:11 +0000] "GET /assets/ace-Bj5lQZzX.js HTTP/1.1" 200 578640 189
2026-08-19 07:25:11.762 [reactor-http-epoll-1] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/ExportIcon-hB54pjUy.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000057838230@643fac44
2026-08-19 07:25:11.763 [reactor-http-epoll-1] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:25:11.762 [reactor-http-epoll-2] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/constants-BZRZA7RH.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000057838230@643fac44
2026-08-19 07:25:11.763 [reactor-http-epoll-2] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:25:11.767 [reactor-http-epoll-2] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/utils-CH284mxw.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000057838230@643fac44
2026-08-19 07:25:11.767 [reactor-http-epoll-2] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:25:11.767 [reactor-http-epoll-1] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/Search-D1de03s6.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000057838230@643fac44
2026-08-19 07:25:11.768 [reactor-http-epoll-1] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:25:11.771 [reactor-http-epoll-2] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.98.81 - - [19/Aug/2026:07:25:11 +0000] "GET /assets/constants-BZRZA7RH.js HTTP/1.1" 200 595 10
2026-08-19 07:25:11.772 [reactor-http-epoll-2] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.98.81 - - [19/Aug/2026:07:25:11 +0000] "GET /assets/utils-CH284mxw.js HTTP/1.1" 200 7596 7
2026-08-19 07:25:11.776 [reactor-http-epoll-1] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.98.81 - - [19/Aug/2026:07:25:11 +0000] "GET /assets/ExportIcon-hB54pjUy.js HTTP/1.1" 200 898 15
2026-08-19 07:25:11.776 [reactor-http-epoll-2] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/ActionButton-COAQ-YGZ.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000057838230@643fac44
2026-08-19 07:25:11.777 [reactor-http-epoll-2] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:25:11.777 [reactor-http-epoll-1] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.98.81 - - [19/Aug/2026:07:25:11 +0000] "GET /assets/Search-D1de03s6.js HTTP/1.1" 200 4374 11
2026-08-19 07:25:11.777 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/Brokers-B8oyaw7y.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000057838230@643fac44
2026-08-19 07:25:11.777 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:25:11.780 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/exportTableCSV-DP-FmEJv.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000057838230@643fac44
2026-08-19 07:25:11.780 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:25:11.783 [reactor-http-epoll-2] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/BreakableTextCell-DqvTDMqh.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000057838230@643fac44
2026-08-19 07:25:11.783 [reactor-http-epoll-2] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:25:11.783 [reactor-http-epoll-1] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/EditorViewer-VrhowIkD.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000057838230@643fac44
2026-08-19 07:25:11.784 [reactor-http-epoll-1] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:25:11.788 [reactor-http-epoll-2] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.98.81 - - [19/Aug/2026:07:25:11 +0000] "GET /assets/ActionButton-COAQ-YGZ.js HTTP/1.1" 200 665 12
2026-08-19 07:25:11.789 [reactor-http-epoll-2] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.98.81 - - [19/Aug/2026:07:25:11 +0000] "GET /assets/BreakableTextCell-DqvTDMqh.js HTTP/1.1" 200 161 9
2026-08-19 07:25:11.790 [reactor-http-epoll-1] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.98.81 - - [19/Aug/2026:07:25:11 +0000] "GET /assets/EditorViewer-VrhowIkD.js HTTP/1.1" 200 10601 7
2026-08-19 07:25:11.791 [reactor-http-epoll-4] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.98.81 - - [19/Aug/2026:07:25:11 +0000] "GET /assets/exportTableCSV-DP-FmEJv.js HTTP/1.1" 200 1994 12
2026-08-19 07:25:11.793 [reactor-http-epoll-4] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.98.81 - - [19/Aug/2026:07:25:11 +0000] "GET /assets/Brokers-B8oyaw7y.js HTTP/1.1" 200 9973 19
2026-08-19 07:25:11.804 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/clusters/kafka-dev/stats' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@296a887b
2026-08-19 07:25:11.805 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:25:11.820 [reactor-http-epoll-4] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.98.81 - - [19/Aug/2026:07:25:11 +0000] "GET /api/clusters/kafka-dev/stats HTTP/1.1" 200 428 17
2026-08-19 07:25:11.833 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/clusters' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@296a887b
2026-08-19 07:25:11.835 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:25:11.842 [reactor-http-epoll-4] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.98.81 - - [19/Aug/2026:07:25:11 +0000] "GET /api/clusters HTTP/1.1" 200 347 11
2026-08-19 07:25:11.846 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/clusters/kafka-dev/brokers' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@296a887b
2026-08-19 07:25:11.847 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:25:11.912 [reactor-http-epoll-4] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.98.81 - - [19/Aug/2026:07:25:11 +0000] "GET /api/clusters/kafka-dev/brokers HTTP/1.1" 200 621 68
2026-08-19 07:25:12.374 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/Topics-omnPFAqB.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000057838230@643fac44
2026-08-19 07:25:12.375 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:25:12.378 [reactor-http-epoll-4] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.98.81 - - [19/Aug/2026:07:25:12 +0000] "GET /assets/Topics-omnPFAqB.js HTTP/1.1" 200 3408 5
2026-08-19 07:25:12.389 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/ListPage-DlYXLXno.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000057838230@643fac44
2026-08-19 07:25:12.389 [reactor-http-epoll-2] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/PlusIcon-ZsK0o-cX.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000057838230@643fac44
2026-08-19 07:25:12.389 [reactor-http-epoll-1] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/DownloadCsvButton-17ENBEk4.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000057838230@643fac44
2026-08-19 07:25:12.389 [reactor-http-epoll-2] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:25:12.389 [reactor-http-epoll-1] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:25:12.389 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:25:12.393 [reactor-http-epoll-2] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.98.81 - - [19/Aug/2026:07:25:12 +0000] "GET /assets/PlusIcon-ZsK0o-cX.js HTTP/1.1" 200 434 5
2026-08-19 07:25:12.394 [reactor-http-epoll-1] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.98.81 - - [19/Aug/2026:07:25:12 +0000] "GET /assets/DownloadCsvButton-17ENBEk4.js HTTP/1.1" 200 700 6
2026-08-19 07:25:12.394 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/ControlPanel.styled-CWc6yswd.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000057838230@643fac44
2026-08-19 07:25:12.394 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:25:12.397 [reactor-http-epoll-4] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.98.81 - - [19/Aug/2026:07:25:12 +0000] "GET /assets/ListPage-DlYXLXno.js HTTP/1.1" 200 7065 10
2026-08-19 07:25:12.398 [reactor-http-epoll-4] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.98.81 - - [19/Aug/2026:07:25:12 +0000] "GET /assets/ControlPanel.styled-CWc6yswd.js HTTP/1.1" 200 3505 5
2026-08-19 07:25:12.430 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/clusters/kafka-dev/topics' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@296a887b
2026-08-19 07:25:12.430 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:25:12.930 [reactor-http-epoll-4] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.98.81 - - [19/Aug/2026:07:25:12 +0000] "GET /api/clusters/kafka-dev/topics?page=1&perPage=25&showInternal=true&fts=false HTTP/1.1" 200 14817 502
2026-08-19 07:25:13.087 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/ConsumerGroups-i2MEk9wH.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000057838230@643fac44
2026-08-19 07:25:13.088 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:25:13.088 [reactor-http-epoll-1] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/index-N_7uqvWG.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000057838230@643fac44
2026-08-19 07:25:13.089 [reactor-http-epoll-1] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:25:13.089 [reactor-http-epoll-2] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/index-Cj7wsYkN.css' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000057838230@643fac44
2026-08-19 07:25:13.090 [reactor-http-epoll-2] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:25:13.092 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/consumers-Cs9Fl0rn.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000057838230@643fac44
2026-08-19 07:25:13.092 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:25:13.093 [reactor-http-epoll-2] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/Table.styled-Bq0NrV6x.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000057838230@643fac44
2026-08-19 07:25:13.093 [reactor-http-epoll-2] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:25:13.095 [reactor-http-epoll-4] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.98.81 - - [19/Aug/2026:07:25:13 +0000] "GET /assets/consumers-Cs9Fl0rn.js HTTP/1.1" 200 1947 4
2026-08-19 07:25:13.096 [reactor-http-epoll-4] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.98.81 - - [19/Aug/2026:07:25:13 +0000] "GET /assets/ConsumerGroups-i2MEk9wH.js HTTP/1.1" 200 15353 10
2026-08-19 07:25:13.097 [reactor-http-epoll-2] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.98.81 - - [19/Aug/2026:07:25:13 +0000] "GET /assets/Table.styled-Bq0NrV6x.js HTTP/1.1" 200 2936 6
2026-08-19 07:25:13.097 [reactor-http-epoll-2] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.98.81 - - [19/Aug/2026:07:25:13 +0000] "GET /assets/index-Cj7wsYkN.css HTTP/1.1" 200 21912 10
2026-08-19 07:25:13.100 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/ControlledSelect-0wvfMNq1.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000057838230@643fac44
2026-08-19 07:25:13.100 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:25:13.100 [reactor-http-epoll-1] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/Form.styled-BOcoibvk.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000057838230@643fac44
2026-08-19 07:25:13.101 [reactor-http-epoll-1] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:25:13.114 [reactor-http-epoll-4] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.98.81 - - [19/Aug/2026:07:25:13 +0000] "GET /assets/ControlledSelect-0wvfMNq1.js HTTP/1.1" 200 522 15
2026-08-19 07:25:13.116 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/queryPersister-CkyJ1WEQ.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000057838230@643fac44
2026-08-19 07:25:13.116 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:25:13.118 [reactor-http-epoll-4] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.98.81 - - [19/Aug/2026:07:25:13 +0000] "GET /assets/queryPersister-CkyJ1WEQ.js HTTP/1.1" 200 1159 3
2026-08-19 07:25:13.119 [reactor-http-epoll-1] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.98.81 - - [19/Aug/2026:07:25:13 +0000] "GET /assets/Form.styled-BOcoibvk.js HTTP/1.1" 200 419 20
2026-08-19 07:25:13.120 [reactor-http-epoll-1] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.98.81 - - [19/Aug/2026:07:25:13 +0000] "GET /assets/index-N_7uqvWG.js HTTP/1.1" 200 155211 33
2026-08-19 07:25:13.153 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/clusters/kafka-dev/consumer-groups/paged' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@296a887b
2026-08-19 07:25:13.154 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:25:13.339 [reactor-http-epoll-4] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.98.81 - - [19/Aug/2026:07:25:13 +0000] "GET /api/clusters/kafka-dev/consumer-groups/paged?page=1&perPage=25&search=&fts=false HTTP/1.1" 200 10261 187
2026-08-19 07:25:13.358 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/clusters/kafka-dev/consumer-groups/lag' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@296a887b
2026-08-19 07:25:13.359 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:25:13.401 [reactor-http-epoll-4] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.98.81 - - [19/Aug/2026:07:25:13 +0000] "GET /api/clusters/kafka-dev/consumer-groups/lag?ids=00000000-0000-0000-0000-000000000000%2C1ad110bf-8495-45c3-ad86-f381aba5d498%2C233a2246-4058-4372-9152-64da5300d8d4%2C8a6d34d8-ba47-4f14-94f8-4a11edbb5090%2C9709eab5-a62c-4e14-86c8-788b0093aeb2%2C9de4d6a0-517b-4430-8f6b-41d5ad66d7b6%2CAutostradaConsumer%2CAutostradaConsumerTst%2CCRM_EVENTS_MANAGER_DEV%2CCRM_EVENTS_MANAGER_QA%2CConfluentTelemetryReporterSampler--1376390082729492237%2CConfluentTelemetryReporterSampler--1514169218269441824%2CConfluentTelemetryReporterSampler--1825185569671062292%2CConfluentTelemetryReporterSampler--1940318048761466766%2CConfluentTelemetryReporterSampler--2323082807454977515%2CConfluentTelemetryReporterSampler--2600373244947787954%2CConfluentTelemetryReporterSampler--3141836770791098188%2CConfluentTelemetryReporterSampler--3273925817795670735%2CConfluentTelemetryReporterSampler--3976257489741481908%2CConfluentTelemetryReporterSampler--4349492312950127819%2CConfluentTelemetryReporterSampler--8899467541848480339%2CConfluentTelemetryReporterSampler--960951064319115256%2CConfluentTelemetryReporterSampler-1781726918189364072%2CConfluentTelemetryReporterSampler-2505996583812895036%2CConfluentTelemetryReporterSampler-2615068261816032270&includePartitions=false HTTP/1.1" 200 4454 45
2026-08-19 07:25:15.681 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/ACLPage-ZpGZoQxO.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000057838230@643fac44
2026-08-19 07:25:15.682 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:25:15.682 [reactor-http-epoll-1] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/TableCells-fkcKFKS_.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000057838230@643fac44
2026-08-19 07:25:15.682 [reactor-http-epoll-1] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:25:15.686 [reactor-http-epoll-1] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.98.81 - - [19/Aug/2026:07:25:15 +0000] "GET /assets/TableCells-fkcKFKS_.js HTTP/1.1" 200 7966 5
2026-08-19 07:25:15.686 [reactor-http-epoll-4] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.98.81 - - [19/Aug/2026:07:25:15 +0000] "GET /assets/ACLPage-ZpGZoQxO.js HTTP/1.1" 200 8942 6
2026-08-19 07:25:15.709 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/clusters/kafka-dev/acls' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@296a887b
2026-08-19 07:25:15.710 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:25:15.857 [reactor-http-epoll-4] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.98.81 - - [19/Aug/2026:07:25:15 +0000] "GET /api/clusters/kafka-dev/acls?search=&fts=false HTTP/1.1" 200 269614 149
2026-08-19 07:25:57.133 [parallel-3] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/info' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@296a887b
2026-08-19 07:25:57.134 [parallel-3] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization failed: Access Denied
2026-08-19 07:25:57.137 [parallel-4] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/clusters' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@296a887b
2026-08-19 07:25:57.137 [parallel-4] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization failed: Access Denied
2026-08-19 07:25:57.138 [reactor-http-epoll-3] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.104.143 - - [19/Aug/2026:07:25:57 +0000] "GET /api/info HTTP/1.1" 302 0 7
2026-08-19 07:25:57.138 [reactor-http-epoll-1] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.104.143 - - [19/Aug/2026:07:25:57 +0000] "GET /api/clusters HTTP/1.1" 302 0 6
2026-08-19 07:25:57.142 [parallel-2] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/clusters/kafka-dev/topics/Realtime.Payments.B2C.TEXT001.V1/connectors' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@296a887b
2026-08-19 07:25:57.142 [parallel-1] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/clusters/kafka-dev/topics/Realtime.Payments.B2C.TEXT001.V1' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@296a887b
2026-08-19 07:25:57.142 [parallel-1] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization failed: Access Denied
2026-08-19 07:25:57.142 [parallel-2] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization failed: Access Denied
2026-08-19 07:25:57.144 [reactor-http-epoll-2] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.104.143 - - [19/Aug/2026:07:25:57 +0000] "GET /api/clusters/kafka-dev/topics/Realtime.Payments.B2C.TEXT001.V1 HTTP/1.1" 302 0 3
2026-08-19 07:25:57.144 [reactor-http-epoll-4] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.104.143 - - [19/Aug/2026:07:25:57 +0000] "GET /api/clusters/kafka-dev/topics/Realtime.Payments.B2C.TEXT001.V1/connectors HTTP/1.1" 302 0 3
2026-08-19 07:25:57.145 [reactor-http-epoll-1] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.104.143 - - [19/Aug/2026:07:25:57 +0000] "GET /login HTTP/1.1" 200 1816 1
2026-08-19 07:25:57.149 [reactor-http-epoll-1] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.104.143 - - [19/Aug/2026:07:25:57 +0000] "GET /login HTTP/1.1" 200 1816 1
2026-08-19 07:25:57.153 [reactor-http-epoll-1] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.104.143 - - [19/Aug/2026:07:25:57 +0000] "GET /login HTTP/1.1" 200 1816 1
2026-08-19 07:25:57.156 [reactor-http-epoll-1] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.104.143 - - [19/Aug/2026:07:25:57 +0000] "GET /login HTTP/1.1" 200 1816 1
2026-08-19 07:25:58.159 [parallel-3] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/clusters' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@296a887b
2026-08-19 07:25:58.160 [parallel-3] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization failed: Access Denied
2026-08-19 07:25:58.160 [parallel-4] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/clusters/kafka-dev/topics/Realtime.Payments.B2C.TEXT001.V1' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@296a887b
2026-08-19 07:25:58.161 [parallel-4] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization failed: Access Denied
2026-08-19 07:25:58.162 [reactor-http-epoll-4] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.104.143 - - [19/Aug/2026:07:25:58 +0000] "GET /api/clusters/kafka-dev/topics/Realtime.Payments.B2C.TEXT001.V1 HTTP/1.1" 302 0 3
2026-08-19 07:25:58.163 [reactor-http-epoll-1] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.104.143 - - [19/Aug/2026:07:25:58 +0000] "GET /api/clusters HTTP/1.1" 302 0 6
2026-08-19 07:25:58.165 [parallel-1] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/clusters/kafka-dev/topics/Realtime.Payments.B2C.TEXT001.V1/connectors' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@296a887b
2026-08-19 07:25:58.165 [parallel-1] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization failed: Access Denied
2026-08-19 07:25:58.167 [reactor-http-epoll-2] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.104.143 - - [19/Aug/2026:07:25:58 +0000] "GET /api/clusters/kafka-dev/topics/Realtime.Payments.B2C.TEXT001.V1/connectors HTTP/1.1" 302 0 3
2026-08-19 07:25:58.168 [reactor-http-epoll-1] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.104.143 - - [19/Aug/2026:07:25:58 +0000] "GET /login HTTP/1.1" 200 1816 1
2026-08-19 07:25:58.172 [reactor-http-epoll-1] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.104.143 - - [19/Aug/2026:07:25:58 +0000] "GET /login HTTP/1.1" 200 1816 1
2026-08-19 07:25:58.175 [reactor-http-epoll-2] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.104.143 - - [19/Aug/2026:07:25:58 +0000] "GET /login HTTP/1.1" 200 1816 1
2026-08-19 07:28:19.651 [parallel-2] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/info' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@296a887b
2026-08-19 07:28:19.652 [parallel-3] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/clusters' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@296a887b
2026-08-19 07:28:19.652 [parallel-3] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization failed: Access Denied
2026-08-19 07:28:19.652 [parallel-2] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization failed: Access Denied
2026-08-19 07:28:19.654 [reactor-http-epoll-2] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.64.164 - - [19/Aug/2026:07:28:19 +0000] "GET /api/info HTTP/1.1" 302 0 7
2026-08-19 07:28:19.654 [reactor-http-epoll-1] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.64.164 - - [19/Aug/2026:07:28:19 +0000] "GET /api/clusters HTTP/1.1" 302 0 4
2026-08-19 07:28:19.836 [reactor-http-epoll-2] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.64.164 - - [19/Aug/2026:07:28:19 +0000] "GET /login HTTP/1.1" 200 1816 3
2026-08-19 07:28:19.936 [reactor-http-epoll-2] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.64.164 - - [19/Aug/2026:07:28:19 +0000] "GET /login HTTP/1.1" 200 1816 2
2026-08-19 07:28:28.780 [parallel-4] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/info' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@296a887b
2026-08-19 07:28:28.780 [parallel-4] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization failed: Access Denied
2026-08-19 07:28:28.781 [parallel-1] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/clusters' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@296a887b
2026-08-19 07:28:28.781 [parallel-1] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization failed: Access Denied
2026-08-19 07:28:28.782 [reactor-http-epoll-2] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.64.164 - - [19/Aug/2026:07:28:28 +0000] "GET /api/info HTTP/1.1" 302 0 4
2026-08-19 07:28:28.782 [reactor-http-epoll-1] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.64.164 - - [19/Aug/2026:07:28:28 +0000] "GET /api/clusters HTTP/1.1" 302 0 3
2026-08-19 07:28:28.814 [reactor-http-epoll-2] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.64.164 - - [19/Aug/2026:07:28:28 +0000] "GET /login HTTP/1.1" 200 1816 1
2026-08-19 07:28:28.839 [reactor-http-epoll-2] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.64.164 - - [19/Aug/2026:07:28:28 +0000] "GET /login HTTP/1.1" 200 1816 1
2026-08-19 07:29:15.089 [reactor-http-epoll-1] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/clusters/kafka-dev/consumer-groups/lag' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@296a887b
2026-08-19 07:29:15.090 [reactor-http-epoll-1] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:29:15.092 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/clusters/kafka-dev/consumer-groups/paged' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@296a887b
2026-08-19 07:29:15.092 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:29:15.120 [reactor-http-epoll-1] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.98.81 - - [19/Aug/2026:07:29:15 +0000] "GET /api/clusters/kafka-dev/consumer-groups/lag?ids=00000000-0000-0000-0000-000000000000%2C1ad110bf-8495-45c3-ad86-f381aba5d498%2C233a2246-4058-4372-9152-64da5300d8d4%2C8a6d34d8-ba47-4f14-94f8-4a11edbb5090%2C9709eab5-a62c-4e14-86c8-788b0093aeb2%2C9de4d6a0-517b-4430-8f6b-41d5ad66d7b6%2CAutostradaConsumer%2CAutostradaConsumerTst%2CCRM_EVENTS_MANAGER_DEV%2CCRM_EVENTS_MANAGER_QA%2CConfluentTelemetryReporterSampler--1376390082729492237%2CConfluentTelemetryReporterSampler--1514169218269441824%2CConfluentTelemetryReporterSampler--1825185569671062292%2CConfluentTelemetryReporterSampler--1940318048761466766%2CConfluentTelemetryReporterSampler--2323082807454977515%2CConfluentTelemetryReporterSampler--2600373244947787954%2CConfluentTelemetryReporterSampler--3141836770791098188%2CConfluentTelemetryReporterSampler--3273925817795670735%2CConfluentTelemetryReporterSampler--3976257489741481908%2CConfluentTelemetryReporterSampler--4349492312950127819%2CConfluentTelemetryReporterSampler--8899467541848480339%2CConfluentTelemetryReporterSampler--960951064319115256%2CConfluentTelemetryReporterSampler-1781726918189364072%2CConfluentTelemetryReporterSampler-2505996583812895036%2CConfluentTelemetryReporterSampler-2615068261816032270&includePartitions=false HTTP/1.1" 200 4454 34
2026-08-19 07:29:15.235 [reactor-http-epoll-4] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.98.81 - - [19/Aug/2026:07:29:15 +0000] "GET /api/clusters/kafka-dev/consumer-groups/paged?page=1&perPage=25&search=&fts=false HTTP/1.1" 200 10261 149
2026-08-19 07:29:25.537 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/clusters/kafka-dev/topics' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@296a887b
2026-08-19 07:29:25.537 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:29:25.871 [reactor-http-epoll-4] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.98.81 - - [19/Aug/2026:07:29:25 +0000] "GET /api/clusters/kafka-dev/topics?page=1&perPage=25&showInternal=true&fts=false HTTP/1.1" 200 14817 336
2026-08-19 07:29:27.652 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/clusters' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@296a887b
2026-08-19 07:29:27.653 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:29:27.654 [reactor-http-epoll-1] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/clusters/kafka-dev/stats' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@296a887b
2026-08-19 07:29:27.654 [reactor-http-epoll-1] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:29:27.658 [reactor-http-epoll-4] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.98.81 - - [19/Aug/2026:07:29:27 +0000] "GET /api/clusters HTTP/1.1" 200 347 7
2026-08-19 07:29:27.658 [reactor-http-epoll-1] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.98.81 - - [19/Aug/2026:07:29:27 +0000] "GET /api/clusters/kafka-dev/stats HTTP/1.1" 200 428 5
2026-08-19 07:29:27.660 [reactor-http-epoll-1] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/clusters/kafka-dev/brokers' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@296a887b
2026-08-19 07:29:27.660 [reactor-http-epoll-1] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:29:27.673 [reactor-http-epoll-1] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.98.81 - - [19/Aug/2026:07:29:27 +0000] "GET /api/clusters/kafka-dev/brokers HTTP/1.1" 200 621 14
2026-08-19 07:29:31.264 [reactor-http-epoll-1] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/clusters' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@296a887b
2026-08-19 07:29:31.264 [reactor-http-epoll-1] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:29:31.269 [reactor-http-epoll-1] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.98.81 - - [19/Aug/2026:07:29:31 +0000] "GET /api/clusters HTTP/1.1" 200 347 7
2026-08-19 07:30:50.876 [parallel-2] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/info' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@296a887b
2026-08-19 07:30:50.878 [parallel-2] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization failed: Access Denied
2026-08-19 07:30:50.880 [parallel-3] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/clusters' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@296a887b
2026-08-19 07:30:50.880 [parallel-3] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization failed: Access Denied
2026-08-19 07:30:50.880 [reactor-http-epoll-1] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.109.47 - - [19/Aug/2026:07:30:50 +0000] "GET /api/info HTTP/1.1" 302 0 5
2026-08-19 07:30:50.881 [reactor-http-epoll-2] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.109.47 - - [19/Aug/2026:07:30:50 +0000] "GET /api/clusters HTTP/1.1" 302 0 8
2026-08-19 07:30:50.890 [reactor-http-epoll-2] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.109.47 - - [19/Aug/2026:07:30:50 +0000] "GET /login HTTP/1.1" 200 1816 1
2026-08-19 07:30:50.900 [reactor-http-epoll-2] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.109.47 - - [19/Aug/2026:07:30:50 +0000] "GET /login HTTP/1.1" 200 1816 2
2026-08-19 07:30:51.920 [parallel-4] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/clusters' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@296a887b
2026-08-19 07:30:51.921 [parallel-4] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization failed: Access Denied
2026-08-19 07:30:51.923 [reactor-http-epoll-2] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.109.47 - - [19/Aug/2026:07:30:51 +0000] "GET /api/clusters HTTP/1.1" 302 0 4
2026-08-19 07:30:51.930 [reactor-http-epoll-2] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.109.47 - - [19/Aug/2026:07:30:51 +0000] "GET /login HTTP/1.1" 200 1816 1
2026-08-19 07:30:53.944 [parallel-1] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/clusters' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@296a887b
2026-08-19 07:30:53.944 [parallel-1] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization failed: Access Denied
2026-08-19 07:30:53.946 [reactor-http-epoll-2] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.109.47 - - [19/Aug/2026:07:30:53 +0000] "GET /api/clusters HTTP/1.1" 302 0 4
2026-08-19 07:30:53.954 [reactor-http-epoll-2] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.109.47 - - [19/Aug/2026:07:30:53 +0000] "GET /login HTTP/1.1" 200 1816 1
2026-08-19 07:31:07.943 [SpringApplicationShutdownHook] INFO  o.s.b.w.e.netty.GracefulShutdown -  - - Commencing graceful shutdown. Waiting for active requests to complete
2026-08-19 07:31:07.951 [netty-shutdown] INFO  o.s.b.w.e.netty.GracefulShutdown -  - - Graceful shutdown complete
2026-08-19 07:31:13.427 [kafka-admin-client-thread | kafbat-ui-admin-1787124277-1] INFO  o.a.kafka.common.utils.AppInfoParser -  - - App info kafka.admin.client for kafbat-ui-admin-1787124277-1 unregistered
2026-08-19 07:31:13.433 [kafka-admin-client-thread | kafbat-ui-admin-1787124277-1] INFO  o.a.kafka.common.metrics.Metrics -  - - Metrics scheduler closed
2026-08-19 07:31:13.433 [kafka-admin-client-thread | kafbat-ui-admin-1787124277-1] INFO  o.a.kafka.common.metrics.Metrics -  - - Closing reporter org.apache.kafka.common.metrics.JmxReporter
2026-08-19 07:31:13.433 [kafka-admin-client-thread | kafbat-ui-admin-1787124277-1] INFO  o.a.kafka.common.metrics.Metrics -  - - Metrics reporters closed
2026-08-19 07:31:15.367 [background-preinit] INFO  o.h.validator.internal.util.Version -  - - HV000001: Hibernate Validator 8.0.3.Final
2026-08-19 07:31:15.469 [main] INFO  io.kafbat.ui.KafkaUiApplication -  - - Starting KafkaUiApplication vv1.5.0 using Java 25.0.2 with PID 1 (/api.jar started by kafkaui in /)
2026-08-19 07:31:15.470 [main] INFO  io.kafbat.ui.KafkaUiApplication -  - - No active profile set, falling back to 1 default profile: "default"
2026-08-19 07:31:20.260 [main] INFO  o.s.b.a.e.web.EndpointLinksResolver -  - - Exposing 1 endpoint beneath base path '/actuator'
2026-08-19 07:31:20.545 [main] INFO  i.k.u.config.auth.LdapSecurityConfig -  - - Configuring LDAP authentication.
2026-08-19 07:31:21.516 [main] INFO  o.s.b.w.e.netty.NettyWebServer -  - - Netty started on port 8444 (https)
2026-08-19 07:31:21.542 [main] INFO  io.kafbat.ui.KafkaUiApplication -  - - Started KafkaUiApplication in 6.834 seconds (process running for 7.437)
2026-08-19 07:31:21.914 [boundedElastic-1] INFO  o.a.k.c.admin.AdminClientConfig -  - - AdminClientConfig values: 
	auto.include.jmx.reporter = true
	bootstrap.controllers = []
	bootstrap.servers = [LINX102083TI1:9092]
	client.dns.lookup = use_all_dns_ips
	client.id = kafbat-ui-admin-1787124681-1
	connections.max.idle.ms = 300000
	default.api.timeout.ms = 60000
	enable.metrics.push = true
	metadata.max.age.ms = 300000
	metadata.recovery.strategy = none
	metric.reporters = []
	metrics.num.samples = 2
	metrics.recording.level = INFO
	metrics.sample.window.ms = 30000
	receive.buffer.bytes = 65536
	reconnect.backoff.max.ms = 1000
	reconnect.backoff.ms = 50
	request.timeout.ms = 30000
	retries = 2147483647
	retry.backoff.max.ms = 1000
	retry.backoff.ms = 100
	sasl.client.callback.handler.class = null
	sasl.jaas.config = null
	sasl.kerberos.kinit.cmd = /usr/bin/kinit
	sasl.kerberos.min.time.before.relogin = 60000
	sasl.kerberos.service.name = null
	sasl.kerberos.ticket.renew.jitter = 0.05
	sasl.kerberos.ticket.renew.window.factor = 0.8
	sasl.login.callback.handler.class = null
	sasl.login.class = null
	sasl.login.connect.timeout.ms = null
	sasl.login.read.timeout.ms = null
	sasl.login.refresh.buffer.seconds = 300
	sasl.login.refresh.min.period.seconds = 60
	sasl.login.refresh.window.factor = 0.8
	sasl.login.refresh.window.jitter = 0.05
	sasl.login.retry.backoff.max.ms = 10000
	sasl.login.retry.backoff.ms = 100
	sasl.mechanism = GSSAPI
	sasl.oauthbearer.clock.skew.seconds = 30
	sasl.oauthbearer.expected.audience = null
	sasl.oauthbearer.expected.issuer = null
	sasl.oauthbearer.header.urlencode = false
	sasl.oauthbearer.jwks.endpoint.refresh.ms = 3600000
	sasl.oauthbearer.jwks.endpoint.retry.backoff.max.ms = 10000
	sasl.oauthbearer.jwks.endpoint.retry.backoff.ms = 100
	sasl.oauthbearer.jwks.endpoint.url = null
	sasl.oauthbearer.scope.claim.name = scope
	sasl.oauthbearer.sub.claim.name = sub
	sasl.oauthbearer.token.endpoint.url = null
	security.protocol = PLAINTEXT
	security.providers = null
	send.buffer.bytes = 131072
	socket.connection.setup.timeout.max.ms = 30000
	socket.connection.setup.timeout.ms = 10000
	ssl.cipher.suites = null
	ssl.enabled.protocols = [TLSv1.2, TLSv1.3]
	ssl.endpoint.identification.algorithm = https
	ssl.engine.factory.class = null
	ssl.key.password = null
	ssl.keymanager.algorithm = SunX509
	ssl.keystore.certificate.chain = null
	ssl.keystore.key = null
	ssl.keystore.location = null
	ssl.keystore.password = null
	ssl.keystore.type = JKS
	ssl.protocol = TLSv1.3
	ssl.provider = null
	ssl.secure.random.implementation = null
	ssl.trustmanager.algorithm = PKIX
	ssl.truststore.certificates = null
	ssl.truststore.location = null
	ssl.truststore.password = null
	ssl.truststore.type = JKS

2026-08-19 07:31:22.136 [boundedElastic-1] INFO  o.a.kafka.common.utils.AppInfoParser -  - - Kafka version: 7.9.5-ccs
2026-08-19 07:31:22.137 [boundedElastic-1] INFO  o.a.kafka.common.utils.AppInfoParser -  - - Kafka commitId: 4cbb817945d2251e
2026-08-19 07:31:22.137 [boundedElastic-1] INFO  o.a.kafka.common.utils.AppInfoParser -  - - Kafka startTimeMs: 1787124682135
2026-08-19 07:31:22.251 [parallel-2] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@4e43643d
2026-08-19 07:31:22.273 [parallel-2] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization failed: Access Denied
2026-08-19 07:31:22.308 [reactor-http-epoll-4] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.98.81 - - [19/Aug/2026:07:31:22 +0000] "GET / HTTP/1.1" 302 0 153
2026-08-19 07:31:22.336 [reactor-http-epoll-4] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.98.81 - - [19/Aug/2026:07:31:22 +0000] "GET /login HTTP/1.1" 200 1816 16
2026-08-19 07:31:22.369 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/index-ToFdRV4e.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000069839a68@4c86af9c
2026-08-19 07:31:22.370 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:31:22.420 [reactor-http-epoll-1] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/index-D3Fzj2d9.css' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000069839a68@4c86af9c
2026-08-19 07:31:22.421 [reactor-http-epoll-1] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:31:22.444 [reactor-http-epoll-2] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/@react-router-D-4KBoK_.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000069839a68@4c86af9c
2026-08-19 07:31:22.444 [reactor-http-epoll-2] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:31:22.524 [reactor-http-epoll-1] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.98.81 - - [19/Aug/2026:07:31:22 +0000] "GET /assets/index-D3Fzj2d9.css HTTP/1.1" 200 1617 120
2026-08-19 07:31:22.559 [reactor-http-epoll-2] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.98.81 - - [19/Aug/2026:07:31:22 +0000] "GET /assets/@react-router-D-4KBoK_.js HTTP/1.1" 200 166169 120
2026-08-19 07:31:22.565 [reactor-http-epoll-4] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.98.81 - - [19/Aug/2026:07:31:22 +0000] "GET /assets/index-ToFdRV4e.js HTTP/1.1" 200 344993 204
2026-08-19 07:31:22.662 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/AuthPage-DYy823dD.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000069839a68@4c86af9c
2026-08-19 07:31:22.663 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:31:22.663 [reactor-http-epoll-2] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/AlertIcon-CaXsK92Y.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000069839a68@4c86af9c
2026-08-19 07:31:22.663 [reactor-http-epoll-2] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:31:22.668 [reactor-http-epoll-2] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.98.81 - - [19/Aug/2026:07:31:22 +0000] "GET /assets/AlertIcon-CaXsK92Y.js HTTP/1.1" 200 684 7
2026-08-19 07:31:22.677 [reactor-http-epoll-4] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.98.81 - - [19/Aug/2026:07:31:22 +0000] "GET /assets/AuthPage-DYy823dD.js HTTP/1.1" 200 23430 17
2026-08-19 07:31:22.688 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/favicon/favicon.svg' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000069839a68@4c86af9c
2026-08-19 07:31:22.689 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:31:22.694 [reactor-http-epoll-2] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/config/authentication' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000069839a68@4c86af9c
2026-08-19 07:31:22.694 [reactor-http-epoll-4] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.98.81 - - [19/Aug/2026:07:31:22 +0000] "GET /favicon/favicon.svg HTTP/1.1" 200 712 7
2026-08-19 07:31:22.694 [reactor-http-epoll-2] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:31:22.742 [parallel-3] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/manifest.json' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000069839a68@4c86af9c
2026-08-19 07:31:22.742 [parallel-3] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:31:22.777 [reactor-http-epoll-3] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.98.81 - - [19/Aug/2026:07:31:22 +0000] "GET /manifest.json HTTP/1.1" 200 249 42
2026-08-19 07:31:22.933 [reactor-http-epoll-2] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.98.81 - - [19/Aug/2026:07:31:22 +0000] "GET /api/config/authentication HTTP/1.1" 200 39 242
2026-08-19 07:31:22.975 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/fonts/Inter-Regular.ttf' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000069839a68@4c86af9c
2026-08-19 07:31:22.976 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:31:22.975 [reactor-http-epoll-2] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/fonts/Inter-Medium.ttf' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000069839a68@4c86af9c
2026-08-19 07:31:22.979 [reactor-http-epoll-2] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:31:23.005 [reactor-http-epoll-4] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.98.81 - - [19/Aug/2026:07:31:22 +0000] "GET /fonts/Inter-Regular.ttf HTTP/1.1" 200 303504 32
2026-08-19 07:31:23.047 [reactor-http-epoll-2] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.98.81 - - [19/Aug/2026:07:31:22 +0000] "GET /fonts/Inter-Medium.ttf HTTP/1.1" 200 308392 73
2026-08-19 07:31:28.257 [parallel-2] WARN  o.a.l.i.v.VectorizationProvider -  - - Java vector incubator module is not readable. For optimal vector performance, pass '--add-modules jdk.incubator.vector' to enable Vector API.
2026-08-19 07:31:32.536 [reactor-http-epoll-2] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.98.81 - - [19/Aug/2026:07:31:31 +0000] "POST /login HTTP/1.1" 302 0 1269
2026-08-19 07:31:32.545 [reactor-http-epoll-2] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@4e43643d
2026-08-19 07:31:32.546 [reactor-http-epoll-2] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:31:32.553 [reactor-http-epoll-2] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.98.81 - - [19/Aug/2026:07:31:32 +0000] "GET / HTTP/1.1" 200 1816 11
2026-08-19 07:31:32.617 [reactor-http-epoll-2] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/info' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@4e43643d
2026-08-19 07:31:32.617 [reactor-http-epoll-2] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:31:32.625 [reactor-http-epoll-2] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.98.81 - - [19/Aug/2026:07:31:32 +0000] "GET /api/info HTTP/1.1" 200 205 10
2026-08-19 07:31:32.637 [reactor-http-epoll-2] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/authorization' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000069839a68@4c86af9c
2026-08-19 07:31:32.637 [reactor-http-epoll-2] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:31:32.652 [reactor-http-epoll-2] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.98.81 - - [19/Aug/2026:07:31:32 +0000] "GET /api/authorization HTTP/1.1" 200 894 16
2026-08-19 07:31:32.666 [reactor-http-epoll-2] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/info' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@4e43643d
2026-08-19 07:31:32.667 [reactor-http-epoll-2] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:31:32.669 [reactor-http-epoll-2] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.98.81 - - [19/Aug/2026:07:31:32 +0000] "GET /api/info HTTP/1.1" 200 205 4
2026-08-19 07:31:32.689 [reactor-http-epoll-2] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/Dashboard-949avtj_.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000069839a68@4c86af9c
2026-08-19 07:31:32.689 [reactor-http-epoll-2] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:31:32.690 [reactor-http-epoll-1] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/Heading.styled-DGSlQalk.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000069839a68@4c86af9c
2026-08-19 07:31:32.691 [reactor-http-epoll-1] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:31:32.691 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/ActionComponent.styled-CtMfGuhc.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000069839a68@4c86af9c
2026-08-19 07:31:32.691 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:31:32.695 [reactor-http-epoll-1] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.98.81 - - [19/Aug/2026:07:31:32 +0000] "GET /assets/Heading.styled-DGSlQalk.js HTTP/1.1" 200 285 6
2026-08-19 07:31:32.698 [reactor-http-epoll-1] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/Switch-DR0XBu1-.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000069839a68@4c86af9c
2026-08-19 07:31:32.698 [reactor-http-epoll-1] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:31:32.699 [reactor-http-epoll-4] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.98.81 - - [19/Aug/2026:07:31:32 +0000] "GET /assets/ActionComponent.styled-CtMfGuhc.js HTTP/1.1" 200 119533 9
2026-08-19 07:31:32.702 [reactor-http-epoll-1] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.98.81 - - [19/Aug/2026:07:31:32 +0000] "GET /assets/Switch-DR0XBu1-.js HTTP/1.1" 200 1130 5
2026-08-19 07:31:32.704 [reactor-http-epoll-2] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.98.81 - - [19/Aug/2026:07:31:32 +0000] "GET /assets/Dashboard-949avtj_.js HTTP/1.1" 200 3137 16
2026-08-19 07:31:32.705 [reactor-http-epoll-1] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/BytesFormatted-QhqsAXvV.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000069839a68@4c86af9c
2026-08-19 07:31:32.706 [reactor-http-epoll-1] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:31:32.706 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/SizeCell-C-hVT6uc.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000069839a68@4c86af9c
2026-08-19 07:31:32.706 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:31:32.707 [reactor-http-epoll-2] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/ActionCanButton-BCx801KA.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000069839a68@4c86af9c
2026-08-19 07:31:32.707 [reactor-http-epoll-2] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:31:32.712 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/assets/localStoragePersister-D-viOm25.js' using org.springframework.security.config.web.server.ServerHttpSecurity$AuthorizeExchangeSpec$Access$$Lambda/0x0000000069839a68@4c86af9c
2026-08-19 07:31:32.713 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:31:32.713 [reactor-http-epoll-1] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.98.81 - - [19/Aug/2026:07:31:32 +0000] "GET /assets/BytesFormatted-QhqsAXvV.js HTTP/1.1" 200 591 9
2026-08-19 07:31:32.714 [reactor-http-epoll-2] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.98.81 - - [19/Aug/2026:07:31:32 +0000] "GET /assets/ActionCanButton-BCx801KA.js HTTP/1.1" 200 456 8
2026-08-19 07:31:32.718 [reactor-http-epoll-4] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.98.81 - - [19/Aug/2026:07:31:32 +0000] "GET /assets/SizeCell-C-hVT6uc.js HTTP/1.1" 200 176 13
2026-08-19 07:31:32.719 [reactor-http-epoll-4] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.98.81 - - [19/Aug/2026:07:31:32 +0000] "GET /assets/localStoragePersister-D-viOm25.js HTTP/1.1" 200 590 9
2026-08-19 07:31:32.763 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.DelegatingReactiveAuthorizationManager -  - - Checking authorization on '/api/clusters' using org.springframework.security.authorization.AuthenticatedReactiveAuthorizationManager@4e43643d
2026-08-19 07:31:32.763 [reactor-http-epoll-4] DEBUG o.s.s.w.s.a.AuthorizationWebFilter -  - - Authorization successful
2026-08-19 07:31:32.792 [reactor-http-epoll-4] INFO  reactor.netty.http.server.AccessLog -  - - 10.81.98.81 - - [19/Aug/2026:07:31:32 +0000] "GET /api/clusters HTTP/1.1" 200 347 31




