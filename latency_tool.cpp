#include <iostream>
#include <chrono>
#include <vector>
#include <algorithm>
#include <cmath>
#include <string>
#include <cstring>
#include <unistd.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <arpa/inet.h>
#include <fcntl.h>
#include <netdb.h>
#include <thread>
#include <atomic>
#include <mutex>
#include <condition_variable>
#include <csignal>
#ifdef __linux__
#include <linux/version.h>
#include <sys/syscall.h>
#include <sys/sysinfo.h>
#include <sys/resource.h>
#include <sys/time.h>
#include <sys/types.h>
#include <sched.h>
#endif

bool safeSend(int socket, const void* buffer, size_t length) {
    ssize_t bytesSent = send(socket, buffer, length, 0);
    if (bytesSent < 0) {
        std::cerr << "Send failed: " << strerror(errno) << std::endl;
        return false;
    }
    return true;
}

bool safeRecv(int socket, void* buffer, size_t length) {
    ssize_t bytesRead = recv(socket, buffer, length, 0);
    if (bytesRead <= 0) {
        if (bytesRead == 0) {
            std::cerr << "Connection closed by peer." << std::endl;
        } else {
            std::cerr << "Recv failed: " << strerror(errno) << std::endl;
        }
        return false;
    }
    return true;
}

int main() {
    int sockfd = socket(AF_INET, SOCK_STREAM, 0);
    if (sockfd < 0) {
        std::cerr << "Socket creation failed: " << strerror(errno) << std::endl;
        return 1;
    }

    struct sockaddr_in server_addr;
    memset(&server_addr, 0, sizeof(server_addr));
    server_addr.sin_family = AF_INET;
    server_addr.sin_port = htons(9876);
    inet_pton(AF_INET, "127.0.0.1", &server_addr.sin_addr);

    if (connect(sockfd, (struct sockaddr*)&server_addr, sizeof(server_addr)) < 0) {
        std::cerr << "Connection failed: " << strerror(errno) << std::endl;
        close(sockfd);
        return 1;
    }

    char buffer[64] = "Ping message";

    if (!safeSend(sockfd, buffer, sizeof(buffer))) {
        close(sockfd);
        return 1;
    }

    if (!safeRecv(sockfd, buffer, sizeof(buffer))) {
        close(sockfd);
        return 1;
    }

    std::cout << "Received response: " << buffer << std::endl;
    close(sockfd);
    return 0;
}