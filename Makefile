
# Makefile for AIX 7 using xlc compiler

# Compiler and flags
CC       = xlc
CFLAGS   = -O2 -q64 -qlanglvl=extc99
LDFLAGS  = -lm
TARGET   = netperf
SRC      = combined-latency-jitter.c

# Build target
all: $(TARGET)

$(TARGET): $(SRC)
	$(CC) $(CFLAGS) -o $(TARGET) $(SRC) $(LDFLAGS)

# Clean target
clean:
	rm -f $(TARGET) *.o core

# Optional: Run netperf in server mode
run-server:
	./$(TARGET) -s

# Optional: Run netperf in client mode (example)
run-client:
	./$(TARGET) -c 127.0.0.1 -n 50 -l 512 -u
