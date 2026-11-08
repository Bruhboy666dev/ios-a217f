#include "a135f_metal2vulkan.h"
#include <stdio.h>
#include <stdlib.h>

int main(void)
{
    char name[256] = {0};
    char error[2048] = {0};
    void *device = a135f_m2v_device_create();
    if (device == NULL) {
        a135f_m2v_last_error(error, sizeof(error));
        fprintf(stderr, "a135f-vulkan-smoke: Vulkan device creation failed: %s\n", error);
        return 1;
    }
    a135f_m2v_device_name(device, name, sizeof(name));
    printf("a135f-vulkan-smoke: Vulkan device created: %s (registryID=%llu)\n",
           name, (unsigned long long)a135f_m2v_registry_id(device));
    a135f_m2v_device_destroy(device);
    return 0;
}
