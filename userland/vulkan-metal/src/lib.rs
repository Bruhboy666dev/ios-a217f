use metal2vulkan_runtime::{Device, DeviceOptions, ShaderCacheOptions};
use std::ffi::{c_char, c_void, CString};
use std::path::PathBuf;
use std::sync::{Mutex, OnceLock};

const LOADER: &str = "/usr/local/lib/a135f/libvulkan.1.dylib";
const MANIFEST: &str = "/usr/local/share/vulkan/icd.d/a135f-panfrost.json";
const CACHE: &str = "/var/mobile/Library/Caches/a135f-metal2vulkan";

struct DeviceHandle(Device);
static LAST_ERROR: OnceLock<Mutex<CString>> = OnceLock::new();

fn set_error(message: &str) {
    let clean = message.replace('\0', " ");
    if let Ok(mut current) = LAST_ERROR.get_or_init(|| Mutex::new(CString::new("").unwrap())).lock() {
        *current = CString::new(clean).unwrap_or_else(|_| CString::new("unknown error").unwrap());
    }
}

#[no_mangle]
pub extern "C" fn a135f_m2v_device_create() -> *mut c_void {
    std::env::set_var("VK_DRIVER_FILES", MANIFEST);
    std::env::set_var("VK_ICD_FILENAMES", MANIFEST);
    let mut options = DeviceOptions::default();
    options.loader = Some(PathBuf::from(LOADER));
    options.shader_cache = ShaderCacheOptions::in_directory(CACHE);
    match std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| Device::system_default_with(&options))) {
        Ok(Ok(device)) => Box::into_raw(Box::new(DeviceHandle(device))).cast(),
        Ok(Err(error)) => {
            set_error(&format!("{error:?}"));
            std::ptr::null_mut()
        }
        Err(_) => {
            set_error("Metal2Vulkan panicked while creating the Vulkan device");
            std::ptr::null_mut()
        }
    }
}

#[no_mangle]
pub unsafe extern "C" fn a135f_m2v_last_error(output: *mut c_char, capacity: usize) -> usize {
    let guard = LAST_ERROR.get_or_init(|| Mutex::new(CString::new("").unwrap())).lock();
    let Ok(message) = guard else { return 0 };
    let bytes = message.as_bytes_with_nul();
    if !output.is_null() && capacity > 0 {
        let copied = bytes.len().min(capacity);
        std::ptr::copy_nonoverlapping(bytes.as_ptr(), output.cast::<u8>(), copied);
        *output.add(copied - 1) = 0;
    }
    bytes.len()
}

#[no_mangle]
pub unsafe extern "C" fn a135f_m2v_device_name(handle: *const c_void, output: *mut c_char, capacity: usize) -> usize {
    let Some(handle) = handle.cast::<DeviceHandle>().as_ref() else { return 0 };
    let bytes = handle.0.name().as_bytes();
    let required = bytes.len() + 1;
    if !output.is_null() && capacity > 0 {
        let copied = bytes.len().min(capacity - 1);
        std::ptr::copy_nonoverlapping(bytes.as_ptr(), output.cast::<u8>(), copied);
        *output.add(copied) = 0;
    }
    required
}

#[no_mangle]
pub unsafe extern "C" fn a135f_m2v_device_destroy(handle: *mut c_void) {
    if !handle.is_null() {
        drop(Box::from_raw(handle.cast::<DeviceHandle>()));
    }
}

#[no_mangle]
pub unsafe extern "C" fn a135f_m2v_registry_id(handle: *const c_void) -> u64 {
    handle.cast::<DeviceHandle>().as_ref().map_or(0, |h| h.0.registry_id())
}
