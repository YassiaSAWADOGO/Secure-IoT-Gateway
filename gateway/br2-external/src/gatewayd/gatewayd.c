#include <signal.h>
#include <syslog.h>
#include <unistd.h>

static volatile sig_atomic_t running = 1;

static void on_signal(int sig)
{
    (void)sig;
    running = 0;            /* demande d'arrêt : la boucle principale se terminera */
}

int main(void)
{
    signal(SIGTERM, on_signal);   /* arrêt demandé par le système (script d'arrêt) */
    signal(SIGINT, on_signal);    /* Ctrl+C, utile pendant les tests */

    openlog("gatewayd", LOG_PID, LOG_DAEMON);
    syslog(LOG_INFO, "started");

    unsigned long n = 0;
    while (running) {
        syslog(LOG_INFO, "alive (%lu)", n++);
        sleep(10);
    }

    syslog(LOG_INFO, "stopping");
    closelog();
    return 0;
}
