# Network Performance Tools

Cross-platform network latency and jitter measurement tools for AIX and Linux.

## 🎯 Features

- **TCP Latency Measurement** - Round-trip time testing
- **Jitter Analysis** - Network stability monitoring
- **Server/Client Modes** - Flexible testing
- **Multiple Implementations** - C, C++, Java, Shell
- **Cross-Platform** - AIX, Linux, macOS

## 📋 Files

| File | Language | Purpose | Size |
|------|----------|---------|------|
| `latency_tool.cpp` | C++ | Main latency tool | 2.2 KB |
| `combined-latency-jitter.c` | C | Advanced latency+jitter | 38 KB |
| `improved-latency-tool.sh` | Shell | Build script | 125 lines |
| `aix-network-latency-tool.java.txt` | Java | AIX implementation | 21 KB |
| `prox.java` | Java | Proxy utility | 15 KB |
| `test.c` | C | Test program | 1.2 KB |
| `Makefile` | Make | Build configuration | 176 bytes |

## 🚀 Quick Start

### Build C/C++ Version

```bash
# Automated build
./improved-latency-tool.sh
make

# Manual build
gcc -o latency_tool latency_tool.cpp -lstdc++
# or
g++ -o latency_tool latency_tool.cpp
```

### Build Java Version (AIX)

```bash
# Rename and compile
mv aix-network-latency-tool.java.txt LatencyTool.java
javac LatencyTool.java
```

## 🎮 Usage

### C/C++ Version

#### Server Mode
```bash
# Default port (9876)
./latency_tool

# Custom port
./latency_tool --port 4444
```

#### Client Mode
```bash
# Connect to localhost
./latency_tool --client

# Connect to specific host
./latency_tool --client 192.168.1.50

# Custom port
./latency_tool --client 192.168.1.50 9999
```

### Java Version

```bash
# Server mode
java LatencyTool server 9876

# Client mode
java LatencyTool client 192.168.1.50 9876
```

## 📊 Output Examples

### Server Output
```
Starting TCP server on port 9876...
Listening for connections...
Client connected from 192.168.1.100:52341
Received: Ping message
Sent: Ping message
```

### Client Output
```
Connecting to 192.168.1.50:9876...
Connected successfully
Sent: Ping message
Received: Ping message
Round-trip time: 1.23 ms
```

## 🖥️ Platform Support

| Feature | AIX | Linux | macOS | Windows |
|---------|-----|-------|-------|---------|
| C/C++ Version | ✅ | ✅ | ✅ | ⚠️ WSL |
| Java Version | ✅ | ✅ | ✅ | ✅ |
| Build Script | ✅ | ✅ | ✅ | ❌ |

## 🔧 Build Requirements

### AIX
- GCC from AIX Toolbox for Linux Applications
- Or IBM XL C/C++ compiler
- Java 8+ (for Java version)

### Linux
- GCC 4.8+ or Clang 3.5+
- Make
- Java 8+ (for Java version)

### macOS
- Xcode Command Line Tools
- Or Homebrew GCC
- Java 8+ (for Java version)

## 📖 Advanced Usage

### Testing Network Latency Between Servers

```bash
# On Server A (192.168.1.10)
./latency_tool --port 9876

# On Server B (192.168.1.20)
./latency_tool --client 192.168.1.10 9876

# Result shows one-way network latency
```

### Testing Bidirectional Latency

```bash
# Terminal 1: Server A
./latency_tool --port 9876

# Terminal 2: Server B
./latency_tool --port 9877

# Terminal 3: Test A -> B
./latency_tool --client server-a 9876

# Terminal 4: Test B -> A
./latency_tool --client server-b 9877
```

### Automated Testing Script

```bash
#!/bin/bash
# test_latency.sh

SERVER="192.168.1.50"
PORT="9876"
TESTS=10

for i in $(seq 1 $TESTS); do
    echo "Test $i:"
    ./latency_tool --client $SERVER $PORT
    sleep 1
done
```

## 🔍 Understanding Results

### Latency Thresholds

| Latency | Quality | Use Case |
|---------|---------|----------|
| < 1 ms | Excellent | Same datacenter |
| 1-10 ms | Good | Same region |
| 10-50 ms | Fair | Different regions |
| 50-100 ms | Poor | Intercontinental |
| > 100 ms | Bad | High latency link |

### Common Latency Values

- **LAN:** 0.5-2 ms
- **Metropolitan:** 2-10 ms
- **Regional:** 10-50 ms
- **Continental:** 50-150 ms
- **Intercontinental:** 150-300 ms
- **Satellite:** 500-700 ms

## ⚠️ Troubleshooting

### "Permission denied" on port < 1024
```bash
# Use port > 1024
./latency_tool --port 9876

# Or run as root (not recommended)
sudo ./latency_tool --port 80
```

### "Connection refused"
```bash
# Check if server is running
ps aux | grep latency_tool

# Check firewall
# AIX
lsfilt

# Linux
iptables -L
firewall-cmd --list-all
```

### "Address already in use"
```bash
# Find process using the port
# AIX
netstat -an | grep 9876

# Linux
ss -tlnp | grep 9876
lsof -i :9876

# Kill the process
kill <PID>
```

## 📚 Related Tools

- **ping** - ICMP echo request/reply
- **traceroute** - Path discovery
- **mtr** - Combined ping and traceroute
- **iperf** - Network bandwidth testing
- **netperf** - Network performance benchmark

## 🤝 Contributing

Improvements welcome! Please:
- Test on both AIX and Linux
- Ensure backward compatibility
- Add comments for complex code
- Update documentation

---

**Platforms:** AIX, Linux, macOS, Windows (WSL)
**Languages:** C, C++, Java, Shell
**Status:** Production Ready
