CXX = g++
CXXFLAGS = -std=c++17 -O2 -pthread

all: latency_tool

latency_tool: latency_tool.cpp
	$(CXX) $(CXXFLAGS) latency_tool.cpp -o latency_tool

clean:
	rm -f latency_tool