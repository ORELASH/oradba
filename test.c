
#define _ALL_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <stdint.h>
#include <sys/time.h>
#include <signal.h>

// תצוגה לדוגמה - ממשק בסיסי בלבד לצורך הקימפול
void print_usage(const char* prog_name) {
    printf("Usage: %s [-s | -c server_ip]\n", prog_name);
}

// פונקציה שמחזירה timestamp במיקרושניות
uint64_t get_timestamp_usec() {
    struct timeval tv;
    gettimeofday(&tv, NULL);
    return (uint64_t)(tv.tv_sec * 1000000 + tv.tv_usec);
}

// סימולציה של התחלה
int main(int argc, char *argv[]) {
    printf("Enhanced Netperf Tool (demo)\n");
    if (argc < 2) {
        print_usage(argv[0]);
        return 1;
    }

    if (strcmp(argv[1], "-s") == 0) {
        printf("Running in server mode...\n");
        // פה ייכנס הקוד המלא של run_tcp_server וכו'
    } else if (strcmp(argv[1], "-c") == 0 && argc > 2) {
        printf("Running in client mode, connecting to: %s\n", argv[2]);
        // פה ייכנס הקוד של run_tcp_client וכו'
    } else {
        print_usage(argv[0]);
        return 1;
    }

    return 0;
}
