/**
 * Enhanced Network Performance Measurement Tool
 * 
 * This program can function as either a server or a client for comprehensive network performance testing.
 * It measures one-way latency, round-trip time (RTT), jitter, and packet loss between network endpoints.
 * 
 * AIX Compatibility:
 * Compile with: gcc -O2 -std=gnu99 -D_ALL_SOURCE -o netperf combined-latency-jitter.c -lm
 * 
 * Usage:
 *   Server mode: ./netperf -s [-p port] [-u] [-6]
 *   Client mode: ./netperf -c server_ip [-p port] [-u] [-n num_packets] [-d delay_ms] [-l packet_size] 
 *                          [-r rate] [-o output_file] [-6] [-t]
 */

/* Define AIX compatibility features */
#define _ALL_SOURCE

/* Order of includes is important for AIX with GCC to avoid conflicts */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <errno.h>
#include <stdint.h>

/* AIX-specific includes */
#ifdef _AIX
#include <sys/machine.h>  /* For byte-order functions specific to AIX */
#endif

/* Network includes */
#include <sys/types.h>
#include <sys/socket.h>
#include <sys/time.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <netdb.h>

/* Additional includes */
#include <time.h>
#include <math.h>
#include <signal.h>
#include <fcntl.h>

// Default parameters
#define DEFAULT_PORT 8888
#define DEFAULT_NUM_PACKETS 100
#define DEFAULT_DELAY_MS 100
#define MIN_PACKET_SIZE 64
#define DEFAULT_PACKET_SIZE 1024
#define MAX_PACKET_SIZE 8192
#define DEFAULT_RATE_PPS 10  // packets per second

// Protocol settings
#define PROTOCOL_TCP 0
#define PROTOCOL_UDP 1

// Global variables for signal handling
int running = 1;
int server_socket = -1;

// Packet structure with variable payload size
typedef struct {
    uint64_t seq_num;        // Sequence number for packet loss detection
    uint64_t client_send;    // Timestamp when client sent the packet
    uint64_t server_recv;    // Timestamp when server received the packet
    uint64_t server_send;    // Timestamp when server sent response
    uint64_t client_recv;    // Timestamp when client received response
    uint32_t packet_size;    // Size of this packet in bytes
    uint8_t payload[];       // Variable-sized payload (C99 flexible array member)
} packet_t;

// Test configuration structure
typedef struct config_t {
    int is_server;
    char server_ip[128];     // Support for IPv6 addresses
    int port;
    int protocol;            // TCP or UDP
    int use_ipv6;            // IPv4 or IPv6
    int num_packets;
    int delay_ms;
    int packet_size;
    int rate_pps;            // Packets per second
    int time_sync;           // Whether to use time synchronization
    char output_file[256];
} config_t;

// Forward declarations (after structures are defined)
int init_socket_address(struct sockaddr_storage* addr, const char* host, int port, int use_ipv6);
packet_t* create_packet(int packet_size);
int validate_packet(packet_t* packet);
int64_t synchronize_clocks(int socket_fd, int is_client, int protocol);
void run_tcp_server(config_t* config);
void run_udp_server(config_t* config);
void run_tcp_client(config_t* config);
void run_udp_client(config_t* config);

/**
 * Get current timestamp in microseconds with highest available precision
 */
uint64_t get_timestamp_usec() {
    /* Use gettimeofday for AIX and other systems for better compatibility */
    struct timeval tv;
    gettimeofday(&tv, NULL);
    return (uint64_t)(tv.tv_sec * 1000000 + tv.tv_usec);
}

/**
 * Signal handler for graceful termination
 */
void handle_signal(int sig) {
    printf("\nReceived signal %d, shutting down...\n", sig);
    running = 0;
    if (server_socket >= 0) {
        close(server_socket);
    }
}

/**
 * Display usage information
 */
void print_usage(const char* prog_name) {
    printf("Usage:\n");
    printf("  Server mode: %s -s [-p port] [-u] [-6]\n", prog_name);
    printf("  Client mode: %s -c server_ip [-p port] [-u] [-n num_packets] [-d delay_ms]\n", prog_name);
    printf("                            [-l packet_size] [-r rate] [-o output_file] [-6] [-t]\n\n");
    printf("Options:\n");
    printf("  -s                Run in server mode\n");
    printf("  -c server_ip      Run in client mode, connecting to server_ip\n");
    printf("  -p port           Port to use (default: %d)\n", DEFAULT_PORT);
    printf("  -u                Use UDP instead of TCP\n");
    printf("  -n num_packets    Number of test packets to send (default: %d)\n", DEFAULT_NUM_PACKETS);
    printf("  -d delay_ms       Delay between packets in ms (default: %d)\n", DEFAULT_DELAY_MS);
    printf("  -l packet_size    Size of each packet in bytes (default: %d, min: %d, max: %d)\n", 
           DEFAULT_PACKET_SIZE, MIN_PACKET_SIZE, MAX_PACKET_SIZE);
    printf("  -r rate           Sending rate in packets per second (default: %d)\n", DEFAULT_RATE_PPS);
    printf("  -o output_file    Write results to CSV file\n");
    printf("  -6                Use IPv6 instead of IPv4\n");
    printf("  -t                Enable clock synchronization attempt\n");
    printf("  -h                Display this help message\n");
}

/**
 * Create and allocate a packet with the specified size
 */
packet_t* create_packet(int packet_size) {
    if (packet_size < sizeof(packet_t)) {
        packet_size = sizeof(packet_t);
    }
    
    // Allocate with enough space for the payload
    packet_t* packet = (packet_t*)malloc(packet_size);
    if (packet == NULL) {
        perror("Memory allocation failed");
        exit(EXIT_FAILURE);
    }
    
    memset(packet, 0, packet_size);
    packet->packet_size = packet_size;
    
    // Fill payload with a recognizable pattern
    for (int i = 0; i < packet_size - sizeof(packet_t); i++) {
        packet->payload[i] = (i % 256);
    }
    
    return packet;
}

/**
 * Validate packet integrity (check payload)
 */
int validate_packet(packet_t* packet) {
    if (packet == NULL || packet->packet_size < sizeof(packet_t)) {
        return 0;
    }
    
    // Check payload integrity
    for (int i = 0; i < packet->packet_size - sizeof(packet_t); i++) {
        if (packet->payload[i] != (i % 256)) {
            return 0;
        }
    }
    
    return 1;
}

/**
 * Initialize socket address structure (works with both IPv4 and IPv6)
 */
int init_socket_address(struct sockaddr_storage* addr, const char* host, int port, int use_ipv6) {
    memset(addr, 0, sizeof(struct sockaddr_storage));
    
    if (use_ipv6) {
        struct sockaddr_in6* addr6 = (struct sockaddr_in6*)addr;
        addr6->sin6_family = AF_INET6;
        addr6->sin6_port = htons(port);
        
        if (host == NULL) {
            // Server mode, bind to any address
            addr6->sin6_addr = in6addr_any;
        } else {
            // Client mode, connect to specific host
            if (inet_pton(AF_INET6, host, &addr6->sin6_addr) <= 0) {
                perror("Invalid IPv6 address format");
                return -1;
            }
        }
        return sizeof(struct sockaddr_in6);
    } else {
        struct sockaddr_in* addr4 = (struct sockaddr_in*)addr;
        addr4->sin_family = AF_INET;
        addr4->sin_port = htons(port);
        
        if (host == NULL) {
            // Server mode, bind to any address
            addr4->sin_addr.s_addr = INADDR_ANY;
        } else {
            // Client mode, connect to specific host
            if (inet_pton(AF_INET, host, &addr4->sin_addr) <= 0) {
                perror("Invalid IPv4 address format");
                return -1;
            }
        }
        return sizeof(struct sockaddr_in);
    }
}

/**
 * Attempt to synchronize clocks between client and server
 * This is a simplified approach inspired by PTP (Precision Time Protocol)
 */
int64_t synchronize_clocks(int socket_fd, int is_client, int protocol) {
    if (!is_client) {
        return 0; // Server doesn't adjust time
    }
    
    const int SYNC_ROUNDS = 10;
    int64_t offsets[SYNC_ROUNDS];
    int64_t min_rtt = INT64_MAX;
    int best_round = 0;
    
    printf("Attempting clock synchronization with server...\n");
    
    for (int i = 0; i < SYNC_ROUNDS; i++) {
        uint64_t t1, t2, t3, t4;
        packet_t sync_packet;
        
        // Prepare sync packet
        memset(&sync_packet, 0, sizeof(packet_t));
        sync_packet.seq_num = 0xFFFFFFFF - i; // Special sequence for sync packets
        sync_packet.packet_size = sizeof(packet_t);
        
        // t1: Client send time
        t1 = get_timestamp_usec();
        sync_packet.client_send = t1;
        
        // Send to server
        if (protocol == PROTOCOL_TCP) {
            if (send(socket_fd, &sync_packet, sizeof(packet_t), 0) < 0) {
                perror("Sync send failed");
                continue;
            }
            
            if (recv(socket_fd, &sync_packet, sizeof(packet_t), 0) <= 0) {
                perror("Sync recv failed");
                continue;
            }
        } else {
            struct sockaddr_storage server_addr;
            socklen_t addr_len = sizeof(server_addr);
            
            if (sendto(socket_fd, &sync_packet, sizeof(packet_t), 0, 
                      (struct sockaddr*)&server_addr, addr_len) < 0) {
                perror("Sync UDP send failed");
                continue;
            }
                  
            if (recvfrom(socket_fd, &sync_packet, sizeof(packet_t), 0,
                        (struct sockaddr*)&server_addr, &addr_len) <= 0) {
                perror("Sync UDP recv failed");
                continue;
            }
        }
        
        // t4: Client receive time
        t4 = get_timestamp_usec();
        
        // Extract t2 and t3 from packet
        t2 = sync_packet.server_recv;
        t3 = sync_packet.server_send;
        
        // Calculate RTT and offset
        int64_t rtt = (t4 - t1) - (t3 - t2);
        int64_t offset = ((t2 - t1) + (t3 - t4)) / 2;
        
        offsets[i] = offset;
        
        // Keep track of the round with minimum RTT
        if (rtt < min_rtt) {
            min_rtt = rtt;
            best_round = i;
        }
        
        // Small delay between sync rounds
        usleep(50000); // 50ms
    }
    
    int64_t best_offset = offsets[best_round];
    printf("Clock synchronization complete. Estimated offset: %ld μs (%.2f ms)\n", 
           best_offset, best_offset / 1000.0);
    
    return best_offset;
}

/**
 * Server implementation - TCP protocol
 */
void run_tcp_server(config_t* config) {
    int server_fd, client_fd;
    struct sockaddr_storage address;
    int opt = 1;
    socklen_t addrlen = sizeof(address);
    packet_t* packet_buffer;
    
    // Allocate packet buffer for maximum possible size
    packet_buffer = create_packet(MAX_PACKET_SIZE);
    
    // Create socket
    server_fd = socket(config->use_ipv6 ? AF_INET6 : AF_INET, SOCK_STREAM, 0);
    if (server_fd < 0) {
        perror("Socket creation failed");
        free(packet_buffer);
        exit(EXIT_FAILURE);
    }
    
    // Set socket options
    if (setsockopt(server_fd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt)) < 0) {
        perror("setsockopt failed");
        free(packet_buffer);
        close(server_fd);
        exit(EXIT_FAILURE);
    }
    
    // Setup address structure
    int addr_size = init_socket_address(&address, NULL, config->port, config->use_ipv6);
    if (addr_size < 0) {
        close(server_fd);
        free(packet_buffer);
        exit(EXIT_FAILURE);
    }
    
    // Bind socket
    if (bind(server_fd, (struct sockaddr*)&address, addr_size) < 0) {
        perror("Bind failed");
        close(server_fd);
        free(packet_buffer);
        exit(EXIT_FAILURE);
    }
    
    // Listen for connections
    if (listen(server_fd, 5) < 0) {
        perror("Listen failed");
        close(server_fd);
        free(packet_buffer);
        exit(EXIT_FAILURE);
    }
    
    server_socket = server_fd;  // For signal handler
    printf("TCP server started. Listening on %s port %d...\n", 
           config->use_ipv6 ? "IPv6" : "IPv4", config->port);
    
    while (running) {
        // Accept connection
        client_fd = accept(server_fd, (struct sockaddr*)&address, &addrlen);
        if (client_fd < 0) {
            if (running) {  // Only show error if we're still supposed to be running
                perror("Accept failed");
            }
            break;
        }
        
        // Get client address information
        char client_str[INET6_ADDRSTRLEN];
        int client_port = 0;
        
        if (address.ss_family == AF_INET6) {
            struct sockaddr_in6* addr6 = (struct sockaddr_in6*)&address;
            inet_ntop(AF_INET6, &addr6->sin6_addr, client_str, sizeof(client_str));
            client_port = ntohs(addr6->sin6_port);
        } else {
            struct sockaddr_in* addr4 = (struct sockaddr_in*)&address;
            inet_ntop(AF_INET, &addr4->sin_addr, client_str, sizeof(client_str));
            client_port = ntohs(addr4->sin_port);
        }
        
        printf("TCP connection accepted from [%s]:%d\n", client_str, client_port);
        
        // Process incoming packets
        uint64_t packet_count = 0;
        while (running) {
            // Receive packet header first to determine size
            int bytes_received = recv(client_fd, packet_buffer, sizeof(packet_t), 0);
            if (bytes_received <= 0) {
                break;
            }
            
            // Handle synchronization packets
            if (packet_buffer->seq_num >= 0xFFFFFFFF - 20) {
                // This is a sync packet, just timestamp and return
                packet_buffer->server_recv = get_timestamp_usec();
                packet_buffer->server_send = get_timestamp_usec();
                send(client_fd, packet_buffer, sizeof(packet_t), 0);
                continue;
            }
            
            // Then receive the rest of the packet if needed
            int remaining_bytes = packet_buffer->packet_size - bytes_received;
            if (remaining_bytes > 0) {
                bytes_received += recv(client_fd, ((char*)packet_buffer) + bytes_received, 
                                      remaining_bytes, 0);
            }
            
            if (bytes_received <= 0) {
                printf("Client disconnected after %lu packets\n", packet_count);
                break;
            }
            
            // Update server timestamps
            packet_buffer->server_recv = get_timestamp_usec();
            packet_buffer->server_send = get_timestamp_usec();
            
            // Send packet back to client
            send(client_fd, packet_buffer, packet_buffer->packet_size, 0);
            packet_count++;
        }
        
        // Close client socket
        close(client_fd);
    }
    
    // Clean up
    close(server_fd);
    free(packet_buffer);
    printf("TCP server shutdown complete\n");
}

/**
 * Server implementation - UDP protocol
 */
void run_udp_server(config_t* config) {
    int server_fd;
    struct sockaddr_storage client_addr;
    socklen_t addr_len = sizeof(client_addr);
    packet_t* packet_buffer;
    
    // Allocate packet buffer for maximum possible size
    packet_buffer = create_packet(MAX_PACKET_SIZE);
    
    // Create socket
    server_fd = socket(config->use_ipv6 ? AF_INET6 : AF_INET, SOCK_DGRAM, 0);
    if (server_fd < 0) {
        perror("Socket creation failed");
        free(packet_buffer);
        exit(EXIT_FAILURE);
    }
    
    // Setup address structure
    struct sockaddr_storage server_addr;
    int addr_size = init_socket_address(&server_addr, NULL, config->port, config->use_ipv6);
    if (addr_size < 0) {
        close(server_fd);
        free(packet_buffer);
        exit(EXIT_FAILURE);
    }
    
    // Bind socket
    if (bind(server_fd, (struct sockaddr*)&server_addr, addr_size) < 0) {
        perror("Bind failed");
        close(server_fd);
        free(packet_buffer);
        exit(EXIT_FAILURE);
    }
    
    server_socket = server_fd;  // For signal handler
    printf("UDP server started. Listening on %s port %d...\n", 
           config->use_ipv6 ? "IPv6" : "IPv4", config->port);
    
    // Process incoming datagrams
    while (running) {
        addr_len = sizeof(client_addr);
        
        // Receive datagram
        int bytes_received = recvfrom(server_fd, packet_buffer, MAX_PACKET_SIZE, 0,
                                     (struct sockaddr*)&client_addr, &addr_len);
        
        if (bytes_received <= 0) {
            if (errno != EINTR) {
                perror("UDP receive error");
            }
            continue;
        }
        
        // Get client address information
        char client_str[INET6_ADDRSTRLEN];
        int client_port = 0;
        
        if (client_addr.ss_family == AF_INET6) {
            struct sockaddr_in6* addr6 = (struct sockaddr_in6*)&client_addr;
            inet_ntop(AF_INET6, &addr6->sin6_addr, client_str, sizeof(client_str));
            client_port = ntohs(addr6->sin6_port);
        } else {
            struct sockaddr_in* addr4 = (struct sockaddr_in*)&client_addr;
            inet_ntop(AF_INET, &addr4->sin_addr, client_str, sizeof(client_str));
            client_port = ntohs(addr4->sin_port);
        }
        
        // Update server timestamps
        packet_buffer->server_recv = get_timestamp_usec();
        packet_buffer->server_send = get_timestamp_usec();
        
        // Send response back to the client
        sendto(server_fd, packet_buffer, packet_buffer->packet_size, 0,
              (struct sockaddr*)&client_addr, addr_len);
    }
    
    // Clean up
    close(server_fd);
    free(packet_buffer);
    printf("UDP server shutdown complete\n");
}

/**
 * Client implementation - TCP protocol
 */
void run_tcp_client(config_t* config) {
    int sock = 0;
    struct sockaddr_storage server_addr;
    packet_t* packet;
    double* latencies;
    double* rtts;
    int packets_received = 0;
    FILE* csv_file = NULL;
    int64_t clock_offset = 0;
    
    // Allocate memory for statistics
    latencies = (double*)malloc(config->num_packets * sizeof(double));
    rtts = (double*)malloc(config->num_packets * sizeof(double));
    
    if (latencies == NULL || rtts == NULL) {
        perror("Memory allocation failed");
        exit(EXIT_FAILURE);
    }
    
    // Open output file if specified
    if (config->output_file[0] != '\0') {
        csv_file = fopen(config->output_file, "w");
        if (csv_file == NULL) {
            perror("Failed to open output file");
            exit(EXIT_FAILURE);
        }
        fprintf(csv_file, "seq_num,packet_size,one_way_latency_us,rtt_us,server_processing_us\n");
    }
    
    // Create socket
    sock = socket(config->use_ipv6 ? AF_INET6 : AF_INET, SOCK_STREAM, 0);
    if (sock < 0) {
        perror("Socket creation failed");
        exit(EXIT_FAILURE);
    }
    
    // Setup address structure
    int addr_size = init_socket_address(&server_addr, config->server_ip, config->port, config->use_ipv6);
    if (addr_size < 0) {
        close(sock);
        exit(EXIT_FAILURE);
    }
    
    // Connect to server
    printf("Connecting to %s server %s:%d...\n", 
           config->use_ipv6 ? "IPv6" : "IPv4", config->server_ip, config->port);
           
    if (connect(sock, (struct sockaddr*)&server_addr, addr_size) < 0) {
        perror("Connection failed");
        close(sock);
        exit(EXIT_FAILURE);
    }
    
    printf("Connected. Using TCP protocol.\n");
    
    // Perform clock synchronization if enabled
    if (config->time_sync) {
        clock_offset = synchronize_clocks(sock, 1, PROTOCOL_TCP);
    }
    
    // Allocate packet with specified size
    packet = create_packet(config->packet_size);
    
    printf("Sending %d packets of size %d bytes with %d ms delay (or rate of %d pps)\n", 
           config->num_packets, config->packet_size, config->delay_ms, config->rate_pps);
    printf("Measuring latency and jitter...\n\n");
    
    // Calculate delay between packets based on rate or delay setting
    int actual_delay_us;
    if (config->rate_pps > 0) {
        actual_delay_us = 1000000 / config->rate_pps;
    } else {
        actual_delay_us = config->delay_ms * 1000;
    }
    
    // Send packets and measure response time
    for (int i = 0; i < config->num_packets && running; i++) {
        // Prepare packet
        packet->seq_num = i + 1;
        packet->client_send = get_timestamp_usec();
        packet->server_recv = 0;
        packet->server_send = 0;
        
        // Send packet to server
        send(sock, packet, packet->packet_size, 0);
        
        // Receive response from server
        int bytes_received = recv(sock, packet, sizeof(packet_t), 0);
        if (bytes_received <= 0) {
            printf("Server disconnected\n");
            break;
        }
        
        // Receive the rest of the packet if needed
        int remaining_bytes = packet->packet_size - bytes_received;
        if (remaining_bytes > 0) {
            bytes_received += recv(sock, ((char*)packet) + bytes_received, remaining_bytes, 0);
        }
        
        if (bytes_received <= 0) {
            printf("Server disconnected\n");
            break;
        }
        
        // Record reception time
        packet->client_recv = get_timestamp_usec();
        
        // Validate packet
        if (!validate_packet(packet)) {
            printf("Warning: Received invalid packet (seq=%lu)\n", packet->seq_num);
            continue;
        }
        
        // Calculate measurements with clock offset correction
        double server_processing = packet->server_send - packet->server_recv;
        double rtt = packet->client_recv - packet->client_send;
        
        // Adjust for clock offset if synchronization was performed
        double one_way_latency;
        if (config->time_sync) {
            // Direct calculation using synchronized timestamps
            one_way_latency = (packet->server_recv - clock_offset) - packet->client_send;
        } else {
            // Estimate using RTT
            one_way_latency = (rtt - server_processing) / 2.0;
        }
        
        // Store results
        latencies[packets_received] = one_way_latency;
        rtts[packets_received] = rtt;
        packets_received++;
        
        printf("Packet %lu (%d bytes): One-way Latency = %.3f ms, RTT = %.3f ms\n", 
               packet->seq_num, packet->packet_size, one_way_latency / 1000, rtt / 1000);
        
        // Write to CSV if enabled
        if (csv_file != NULL) {
            fprintf(csv_file, "%lu,%d,%.3f,%.3f,%.3f\n", 
                    packet->seq_num, packet->packet_size, one_way_latency, rtt, server_processing);
        }
        
        // Delay before sending next packet
        usleep(actual_delay_us);
    }
    
    // Calculate statistics
    if (packets_received > 0) {
        // Initialize statistics
        double total_latency = 0;
        double min_latency = latencies[0];
        double max_latency = latencies[0];
        double avg_latency = 0;
        double jitter = 0;
        double std_dev = 0;
        
        double total_rtt = 0;
        double min_rtt = rtts[0];
        double max_rtt = rtts[0];
        double avg_rtt = 0;
        
        // Calculate min, max, avg
        for (int i = 0; i < packets_received; i++) {
            // Latency stats
            total_latency += latencies[i];
            if (latencies[i] < min_latency) min_latency = latencies[i];
            if (latencies[i] > max_latency) max_latency = latencies[i];
            
            // RTT stats
            total_rtt += rtts[i];
            if (rtts[i] < min_rtt) min_rtt = rtts[i];
            if (rtts[i] > max_rtt) max_rtt = rtts[i];
        }
        
        avg_latency = total_latency / packets_received;
        avg_rtt = total_rtt / packets_received;
        
        // Calculate jitter (standard deviation of latencies)
        for (int i = 0; i < packets_received; i++) {
            std_dev += pow(latencies[i] - avg_latency, 2);
        }
        std_dev = sqrt(std_dev / packets_received);
        jitter = std_dev;
        
        // Calculate packet loss
        double packet_loss = 100.0 * (config->num_packets - packets_received) / config->num_packets;
        
        // Calculate throughput (bits per second)
        double test_duration_sec = 0.0;
        if (packets_received > 1) {
            test_duration_sec = (rtts[packets_received-1] - rtts[0]) / 1000000.0 + 
                                (actual_delay_us / 1000000.0);
        } else {
            test_duration_sec = actual_delay_us / 1000000.0;
        }
        
        double throughput_bps = (packets_received * config->packet_size * 8) / test_duration_sec;
        
        // Print summary statistics
        printf("\n--- Latency and Jitter Summary (TCP) ---\n");
        printf("Test configuration:\n");
        printf("  Protocol: TCP over %s\n", config->use_ipv6 ? "IPv6" : "IPv4");
        printf("  Packet size: %d bytes\n", config->packet_size);
        printf("  Packets sent: %d\n", config->num_packets);
        printf("  Packets received: %d\n", packets_received);
        printf("  Packet loss: %.2f%%\n", packet_loss);
        printf("\n");
        printf("One-way Latency:\n");
        printf("  Minimum: %.3f ms\n", min_latency / 1000);
        printf("  Maximum: %.3f ms\n", max_latency / 1000);
        printf("  Average: %.3f ms\n", avg_latency / 1000);
        printf("  Jitter (std deviation): %.3f ms\n", jitter / 1000);
        printf("\n");
        printf("Round-Trip Time (RTT):\n");
        printf("  Minimum: %.3f ms\n", min_rtt / 1000);
        printf("  Maximum: %.3f ms\n", max_rtt / 1000);
        printf("  Average: %.3f ms\n", avg_rtt / 1000);
        printf("\n");
        printf("Throughput:\n");
        printf("  Average: %.2f Kbps (%.2f Mbps)\n", 
               throughput_bps / 1000, throughput_bps / 1000000);
    } else {
        printf("No packets were successfully exchanged\n");
    }
    
    // Close file if open
    if (csv_file != NULL) {
        fclose(csv_file);
        printf("\nResults saved to %s\n", config->output_file);
    }
    
    // Clean up
    free(packet);
    free(latencies);
    free(rtts);
    close(sock);
}

/**
 * Client implementation - UDP protocol
 */
void run_udp_client(config_t* config) {
    int sock = 0;
    struct sockaddr_storage server_addr;
    socklen_t addr_len;
    packet_t* packet;
    double* latencies;
    double* rtts;
    int packets_received = 0;
    FILE* csv_file = NULL;
    int64_t clock_offset = 0;
    
    // Allocate memory for statistics
    latencies = (double*)malloc(config->num_packets * sizeof(double));
    rtts = (double*)malloc(config->num_packets * sizeof(double));
    
    if (latencies == NULL || rtts == NULL) {
        perror("Memory allocation failed");
        exit(EXIT_FAILURE);
    }
    
    // Open output file if specified
    if (config->output_file[0] != '\0') {
        csv_file = fopen(config->output_file, "w");
        if (csv_file == NULL) {
            perror("Failed to open output file");
            exit(EXIT_FAILURE);
        }
        fprintf(csv_file, "seq_num,packet_size,one_way_latency_us,rtt_us,server_processing_us\n");
    }
    
    // Create socket
    sock = socket(config->use_ipv6 ? AF_INET6 : AF_INET, SOCK_DGRAM, 0);
    if (sock < 0) {
        perror("Socket creation failed");
        exit(EXIT_FAILURE);
    }
    
    // Setup address structure
    addr_len = init_socket_address(&server_addr, config->server_ip, config->port, config->use_ipv6);
    if (addr_len < 0) {
        close(sock);
        exit(EXIT_FAILURE);
    }
    
    printf("Using UDP protocol over %s to server %s:%d\n", 
           config->use_ipv6 ? "IPv6" : "IPv4", config->server_ip, config->port);
    
    // Perform clock synchronization if enabled
    if (config->time_sync) {
        // For UDP, we need to "connect" the socket to the server first for synchronization
        if (connect(sock, (struct sockaddr*)&server_addr, addr_len) < 0) {
            perror("UDP connect for synchronization failed");
            close(sock);
            exit(EXIT_FAILURE);
        }
        
        clock_offset = synchronize_clocks(sock, 1, PROTOCOL_UDP);
    }
    
    // Allocate packet with specified size
    packet = create_packet(config->packet_size);
    
    printf("Sending %d packets of size %d bytes with %d ms delay (or rate of %d pps)\n", 
           config->num_packets, config->packet_size, config->delay_ms, config->rate_pps);
    printf("Measuring latency and jitter...\n\n");
    
    // Calculate delay between packets based on rate or delay setting
    int actual_delay_us;
    if (config->rate_pps > 0) {
        actual_delay_us = 1000000 / config->rate_pps;
    } else {
        actual_delay_us = config->delay_ms * 1000;
    }
    
    // For UDP, set a reasonable timeout
    struct timeval tv;
    tv.tv_sec = 1;  // 1 second timeout
    tv.tv_usec = 0;
    if (setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, (char*)&tv, sizeof(tv)) < 0) {
        perror("Setting socket timeout failed");
    }
    
    // Send packets and measure response time
    for (int i = 0; i < config->num_packets && running; i++) {
        // Prepare packet
        packet->seq_num = i + 1;
        packet->client_send = get_timestamp_usec();
        packet->server_recv = 0;
        packet->server_send = 0;
        
        // Send packet to server
        int sent = sendto(sock, packet, packet->packet_size, 0, 
                         (struct sockaddr*)&server_addr, addr_len);
        if (sent < 0) {
            perror("UDP send failed");
            continue;
        }
        
        // Receive response from server
        int bytes_received = recvfrom(sock, packet, packet->packet_size, 0, NULL, NULL);
        if (bytes_received <= 0) {
            printf("Packet %d: No response (timeout)\n", i + 1);
            continue;
        }
        
        // Record reception time
        packet->client_recv = get_timestamp_usec();
        
        // Validate packet
        if (!validate_packet(packet) || packet->seq_num != (i + 1)) {
            printf("Warning: Received invalid or out-of-sequence packet\n");
            continue;
        }
        
        // Calculate measurements with clock offset correction
        double server_processing = packet->server_send - packet->server_recv;
        double rtt = packet->client_recv - packet->client_send;
        
        // Adjust for clock offset if synchronization was performed
        double one_way_latency;
        if (config->time_sync) {
            // Direct calculation using synchronized timestamps
            one_way_latency = (packet->server_recv - clock_offset) - packet->client_send;
        } else {
            // Estimate using RTT
            one_way_latency = (rtt - server_processing) / 2.0;
        }
        
        // Store results
        latencies[packets_received] = one_way_latency;
        rtts[packets_received] = rtt;
        packets_received++;
        
        printf("Packet %lu (%d bytes): One-way Latency = %.3f ms, RTT = %.3f ms\n", 
               packet->seq_num, packet->packet_size, one_way_latency / 1000, rtt / 1000);
        
        // Write to CSV if enabled
        if (csv_file != NULL) {
            fprintf(csv_file, "%lu,%d,%.3f,%.3f,%.3f\n", 
                    packet->seq_num, packet->packet_size, one_way_latency, rtt, server_processing);
        }
        
        // Delay before sending next packet
        usleep(actual_delay_us);
    }
    
    // Calculate statistics
    if (packets_received > 0) {
        // Initialize statistics
        double total_latency = 0;
        double min_latency = latencies[0];
        double max_latency = latencies[0];
        double avg_latency = 0;
        double jitter = 0;
        double std_dev = 0;
        
        double total_rtt = 0;
        double min_rtt = rtts[0];
        double max_rtt = rtts[0];
        double avg_rtt = 0;
        
        // Calculate min, max, avg
        for (int i = 0; i < packets_received; i++) {
            // Latency stats
            total_latency += latencies[i];
            if (latencies[i] < min_latency) min_latency = latencies[i];
            if (latencies[i] > max_latency) max_latency = latencies[i];
            
            // RTT stats
            total_rtt += rtts[i];
            if (rtts[i] < min_rtt) min_rtt = rtts[i];
            if (rtts[i] > max_rtt) max_rtt = rtts[i];
        }
        
        avg_latency = total_latency / packets_received;
        avg_rtt = total_rtt / packets_received;
        
        // Calculate jitter (standard deviation of latencies)
        for (int i = 0; i < packets_received; i++) {
            std_dev += pow(latencies[i] - avg_latency, 2);
        }
        std_dev = sqrt(std_dev / packets_received);
        jitter = std_dev;
        
        // Calculate packet loss
        double packet_loss = 100.0 * (config->num_packets - packets_received) / config->num_packets;
        
        // Calculate throughput (bits per second)
        double test_duration_sec = 0.0;
        if (packets_received > 1) {
            test_duration_sec = (rtts[packets_received-1] - rtts[0]) / 1000000.0 + 
                                (actual_delay_us / 1000000.0);
        } else {
            test_duration_sec = actual_delay_us / 1000000.0;
        }
        
        double throughput_bps = (packets_received * config->packet_size * 8) / test_duration_sec;
        
        // Print summary statistics
        printf("\n--- Latency and Jitter Summary (UDP) ---\n");
        printf("Test configuration:\n");
        printf("  Protocol: UDP over %s\n", config->use_ipv6 ? "IPv6" : "IPv4");
        printf("  Packet size: %d bytes\n", config->packet_size);
        printf("  Packets sent: %d\n", config->num_packets);
        printf("  Packets received: %d\n", packets_received);
        printf("  Packet loss: %.2f%%\n", packet_loss);
        printf("\n");
        printf("One-way Latency:\n");
        printf("  Minimum: %.3f ms\n", min_latency / 1000);
        printf("  Maximum: %.3f ms\n", max_latency / 1000);
        printf("  Average: %.3f ms\n", avg_latency / 1000);
        printf("  Jitter (std deviation): %.3f ms\n", jitter / 1000);
        printf("\n");
        printf("Round-Trip Time (RTT):\n");
        printf("  Minimum: %.3f ms\n", min_rtt / 1000);
        printf("  Maximum: %.3f ms\n", max_rtt / 1000);
        printf("  Average: %.3f ms\n", avg_rtt / 1000);
        printf("\n");
        printf("Throughput:\n");
        printf("  Average: %.2f Kbps (%.2f Mbps)\n", 
               throughput_bps / 1000, throughput_bps / 1000000);
    } else {
        printf("No packets were successfully exchanged\n");
    }
    
    // Close file if open
    if (csv_file != NULL) {
        fclose(csv_file);
        printf("\nResults saved to %s\n", config->output_file);
    }
    
    // Clean up
    free(packet);
    free(latencies);
    free(rtts);
    close(sock);
}

int main(int argc, char *argv[]) {
    int opt;
    config_t config;
    
    // Set default configuration
    memset(&config, 0, sizeof(config_t));
    config.port = DEFAULT_PORT;
    config.protocol = PROTOCOL_TCP;
    config.use_ipv6 = 0;
    config.num_packets = DEFAULT_NUM_PACKETS;
    config.delay_ms = DEFAULT_DELAY_MS;
    config.packet_size = DEFAULT_PACKET_SIZE;
    config.rate_pps = DEFAULT_RATE_PPS;
    config.time_sync = 0;
    
    // Setup signal handling
    signal(SIGINT, handle_signal);
    signal(SIGTERM, handle_signal);
    
    // Parse command line arguments
    while ((opt = getopt(argc, argv, "sc:p:un:d:l:r:o:6th")) != -1) {
        switch (opt) {
            case 's':
                config.is_server = 1;
                break;
            case 'c':
                config.is_server = 0;
                strncpy(config.server_ip, optarg, sizeof(config.server_ip) - 1);
                break;
            case 'p':
                config.port = atoi(optarg);
                break;
            case 'u':
                config.protocol = PROTOCOL_UDP;
                break;
            case 'n':
                config.num_packets = atoi(optarg);
                break;
            case 'd':
                config.delay_ms = atoi(optarg);
                break;
            case 'l':
                config.packet_size = atoi(optarg);
                if (config.packet_size < MIN_PACKET_SIZE) {
                    config.packet_size = MIN_PACKET_SIZE;
                } else if (config.packet_size > MAX_PACKET_SIZE) {
                    config.packet_size = MAX_PACKET_SIZE;
                }
                break;
            case 'r':
                config.rate_pps = atoi(optarg);
                break;
            case 'o':
                strncpy(config.output_file, optarg, sizeof(config.output_file) - 1);
                break;
            case '6':
                config.use_ipv6 = 1;
                break;
            case 't':
                config.time_sync = 1;
                break;
            case 'h':
                print_usage(argv[0]);
                exit(EXIT_SUCCESS);
            default:
                print_usage(argv[0]);
                exit(EXIT_FAILURE);
        }
    }
    
    // Validate arguments
    if (config.is_server) {
        // Run in server mode
        if (config.protocol == PROTOCOL_TCP) {
            run_tcp_server(&config);
        } else {
            run_udp_server(&config);
        }
    } else if (config.server_ip[0] != '\0') {
        // Run in client mode
        if (config.protocol == PROTOCOL_TCP) {
            run_tcp_client(&config);
        } else {
            run_udp_client(&config);
        }
    } else {
        // Invalid arguments
        print_usage(argv[0]);
        exit(EXIT_FAILURE);
    }
    
    return 0;
}
