#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "freertos/semphr.h"
#include "esp_log.h"

#define UTILISER_MUTEX 1          // 0 = sans protection, 1 = avec mutex
#define N 100000                  // nombre d'incréments par tâche

static const char *TAG = "mutex";
static volatile int compteur = 0; // la ressource partagée
static SemaphoreHandle_t verrou;  // le mutex

static void incrementer(void *param)
{
    vTaskDelay(pdMS_TO_TICKS(100));   // attendre que les deux tâches soient créées, pour démarrer ensemble
    for (int i = 0; i < N; i++) {
#if UTILISER_MUTEX
        xSemaphoreTake(verrou, portMAX_DELAY);   // prendre le verrou (attendre s'il est pris)
#endif
        compteur++;                               // la section critique
#if UTILISER_MUTEX
        xSemaphoreGive(verrou);                   // rendre le verrou
#endif
    }
    vTaskDelete(NULL);                // une tâche terminée se supprime elle-même
}

void app_main(void)
{
    verrou = xSemaphoreCreateMutex();
    xTaskCreatePinnedToCore(incrementer, "inc0", 2048, NULL, 5, NULL, 0);  // cœur 0
    xTaskCreatePinnedToCore(incrementer, "inc1", 2048, NULL, 5, NULL, 1);  // cœur 1
    vTaskDelay(pdMS_TO_TICKS(3000));  // laisser le temps aux deux tâches de finir
    ESP_LOGI(TAG, "Attendu : %d, obtenu : %d (mutex %s)",
             2 * N, compteur, UTILISER_MUTEX ? "activé" : "désactivé");
}
