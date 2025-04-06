# Unified Network Latency Tool

A single executable that can act as both server and client for TCP latency testing.

## 🔧 Build Instructions

```bash
chmod +x improved-latency-tool.sh
./improved-latency-tool.sh
make
```

## 🚀 Usage Examples

- Start server on default port (9876):

```bash
./latency_tool
```

- Start server on custom port:

```bash
./latency_tool --port 4444
```

- Start client to connect to localhost:

```bash
./latency_tool --client
```

- Start client to specific IP:

```bash
./latency_tool --client 192.168.1.50
```

- Start client to specific IP and port:

```bash
./latency_tool --client 192.168.1.50 9999
```

## 🧪 What It Does

- Client sends a "Ping message" to the server.
- Server echoes the message back.
- Useful for basic round-trip latency testing and connectivity checks.

## 📄 License

MIT (or specify your own)
