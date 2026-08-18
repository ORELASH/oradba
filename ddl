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
