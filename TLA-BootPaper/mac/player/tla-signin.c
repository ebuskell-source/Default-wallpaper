// tla-signin.c - TLA BootPaper (5.7.0): the Mac app's side of signing in.
//   tla-signin <file> <done-url> [seconds]
// Listens on 127.0.0.1, on a port the system picks (printed on the first line), for the sign-in page handing back
// its answer (GET /callback?...). Writes what came after the "?" to <file> (only the person can read it), sends the
// browser on to <done-url>, and exits 0. Anything else (a browser asking for an icon) gets "not found". Gives up
// after <seconds> (600 by default) with exit code 2.
// Built for Apple silicon and Intel: see build-player.sh (the same as tla-player).
#include <arpa/inet.h>
#include <errno.h>
#include <netinet/in.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/select.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/time.h>
#include <time.h>
#include <unistd.h>

static void reply(int c, const char *text) { send(c, text, strlen(text), 0); }

int main(int argc, char **argv) {
    if (argc < 3) { fprintf(stderr, "usage: tla-signin <file> <done-url> [seconds]\n"); return 64; }
    const char *out = argv[1], *done = argv[2];
    int timeout = argc > 3 ? atoi(argv[3]) : 600;
    if (timeout <= 0 || timeout > 3600) timeout = 600;
    if (strpbrk(done, "\r\n")) return 64;
    signal(SIGPIPE, SIG_IGN);
    umask(077);
    int s = socket(AF_INET, SOCK_STREAM, 0);
    struct sockaddr_in a;
    memset(&a, 0, sizeof a);
    a.sin_family = AF_INET;
    a.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    if (s < 0 || bind(s, (struct sockaddr *)&a, sizeof a) != 0 || listen(s, 8) != 0) { perror("tla-signin"); return 1; }
    socklen_t len = sizeof a;
    getsockname(s, (struct sockaddr *)&a, &len);
    printf("%d\n", ntohs(a.sin_port));
    fflush(stdout);
    time_t end = time(NULL) + timeout;
    for (;;) {
        time_t left = end - time(NULL);
        if (left <= 0) return 2;
        fd_set fds;
        FD_ZERO(&fds);
        FD_SET(s, &fds);
        struct timeval tv = { left, 0 };
        int r = select(s + 1, &fds, NULL, NULL, &tv);
        if (r < 0 && errno == EINTR) continue;
        if (r <= 0) return r == 0 ? 2 : 1;
        int c = accept(s, NULL, NULL);
        if (c < 0) continue;
        struct timeval rt = { 3, 0 };
        setsockopt(c, SOL_SOCKET, SO_RCVTIMEO, &rt, sizeof rt);
        static char buf[32768];
        size_t n = 0;
        buf[0] = 0;
        while (n < sizeof buf - 1) {
            ssize_t k = recv(c, buf + n, sizeof buf - 1 - n, 0);
            if (k <= 0) break;
            n += (size_t)k;
            buf[n] = 0;
            if (strstr(buf, "\r\n\r\n")) break;
        }
        if (strncmp(buf, "GET /callback?", 14) == 0) {
            char *q = buf + 14, *end_q = strpbrk(q, " \r\n");
            if (end_q) *end_q = 0;
            char tmp[4096];
            snprintf(tmp, sizeof tmp, "%s.tmp", out);
            FILE *f = fopen(tmp, "w");
            if (f) { fputs(q, f); fclose(f); rename(tmp, out); }
            char head[2048];
            snprintf(head, sizeof head, "HTTP/1.1 302 Found\r\nLocation: %s\r\nCache-Control: no-store\r\n"
                     "Content-Length: 0\r\nConnection: close\r\n\r\n", done);
            reply(c, head);
            close(c);
            close(s);
            return f ? 0 : 1;
        }
        reply(c, "HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\nConnection: close\r\n\r\n");
        close(c);
    }
}
