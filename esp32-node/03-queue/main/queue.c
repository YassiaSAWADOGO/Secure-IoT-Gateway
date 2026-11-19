#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "freertos/queue.h"
#include "esp_log.h"
#include "esp_random.h"

static const char *TAG = "queue";

typedef struct {               // le « message » transporté par la file
    int numero;
    float temperature;
} mesure_t;

static QueueHandle_t file;     // la boîte aux lettres, partagée par les deux tâches

static void capteur(void *param)
{
    int numero = 0;
    while (1) {
        mesure_t m = { .numero = numero++,
                       .temperature = 20.0f + (esp_random() % 100) / 10.0f };  // fausse mesure

        if (xQueueSend(file, &m, pdMS_TO_TICKS(100)) == pdPASS) {
            ESP_LOGI(TAG, "Capteur : mesure %d déposée (%.1f °C)", m.numero, m.temperature);
        } else {
            ESP_LOGW(TAG, "Capteur : file pleine, mesure %d PERDUE", m.numero);
        }
        vTaskDelay(pdMS_TO_TICKS(1000));          // une mesure par seconde
    }
}

static void envoi(void *param)
{
    mesure_t m;
    while (1) {
        xQueueReceive(file, &m, portMAX_DELAY);   // dort jusqu'à ce qu'un message arrive
        ESP_LOGI(TAG, "Envoi : mesure %d envoyée (%.1f °C), %d en attente",
                 m.numero, m.temperature, uxQueueMessagesWaiting(file));
        vTaskDelay(pdMS_TO_TICKS(2500));          // simule un envoi réseau lent
    }
}

void app_main(void)
{
    file = xQueueCreate(5, sizeof(mesure_t));     // 5 places, de la taille d'une mesure
    xTaskCreate(capteur, "capteur", 3072, NULL, 5, NULL);
    xTaskCreate(envoi,   "envoi",   3072, NULL, 5, NULL);
}
