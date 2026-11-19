#include <string.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "esp_log.h"
#include "esp_rom_sys.h"

static const char *TAG = "prio";

static void rapide(void *param)
{
    int tour = 0;
    while (1) {
        ESP_LOGI(TAG, "Rapide : tour %d", tour++);
        vTaskDelay(pdMS_TO_TICKS(500)); // ATTENTE ACTIVE : occupe le processeur 500 ms
    }
}

static void lente(void *param)
{
    int tour = 0;
    while (1) {
        ESP_LOGI(TAG, "Lente : tour %d", tour++);
        vTaskDelay(pdMS_TO_TICKS(2000)); // PAUSE : rend le processeur pendant 2 s
    }
}

void app_main(void)
{
    //                       fonction, nom,     pile, param, priorité, poignée, cœur
    xTaskCreatePinnedToCore(rapide,   "rapide", 2048, NULL,  6,        NULL,    0);
    xTaskCreatePinnedToCore(lente,    "lente",  2048, NULL,  5,        NULL,    0);
}

