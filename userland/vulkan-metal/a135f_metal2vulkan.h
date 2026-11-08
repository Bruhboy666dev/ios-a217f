#ifndef A135F_METAL2VULKAN_H
#define A135F_METAL2VULKAN_H
#include <stddef.h>
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif
/* Core Vulkan adapter only; not an Objective-C MTLDevice implementation. */
void *a135f_m2v_device_create(void);
size_t a135f_m2v_last_error(char *output, size_t capacity);
size_t a135f_m2v_device_name(const void *handle, char *output, size_t capacity);
void a135f_m2v_device_destroy(void *handle);
uint64_t a135f_m2v_registry_id(const void *handle);
#ifdef __cplusplus
}
#endif
#endif
