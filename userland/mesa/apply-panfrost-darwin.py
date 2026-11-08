#!/usr/bin/env python3
"""Make Mesa's panfrost build and run on iOS over the A135FMali service (userland/mesa/a135f-drm).

  apply-panfrost-darwin.py MESA_SOURCE_DIR

Written against Mesa 25.0.x WITHOUT the source at hand, so every edit is anchored on a regular
expression and checked: a miss is reported by name and the exit status is 1 (nothing half-silently
skipped). If one misses, open the file it names, make the same change by hand (what it is is in the
comment above each edit), and re-run -- finished edits are recognised and left alone.
"""
import os, re, shutil, sys

root = sys.argv[1]
here = os.path.dirname(os.path.abspath(__file__))
failed = []
MARK = 'A135F:'

def edit(path, what, pattern, repl, flags=re.S):
    p = os.path.join(root, path)
    s = open(p).read()
    if MARK in s and ('/* %s %s */' % (MARK, what)) in s:
        print('already: %s: %s' % (path, what)); return
    new, n = re.subn(pattern, lambda m: repl(m) if callable(repl) else repl, s, count=1, flags=flags)
    if n != 1:
        print('MISSED : %s: %s' % (path, what)); failed.append((path, what)); return
    open(p, 'w').write(new); print('done   : %s: %s' % (path, what))

# 1. The libdrm stand-in: Mesa's headers and our two files.
dst = os.path.join(root, 'src/a135f-drm')
shutil.rmtree(dst, ignore_errors=True)
shutil.copytree(os.path.join(here, 'a135f-drm'), dst)

# 2. meson.build (top): on Darwin, panfrost's "libdrm" is the stand-in.
edit('meson.build', 'darwin libdrm for panfrost',
     r'(if dep_libdrm\.found\(\))',
     lambda m: ("if host_machine.system() == 'darwin' and with_gallium_panfrost\n"
                "  # /* A135F: darwin libdrm for panfrost */ no DRM here: src/a135f-drm stands in for libdrm\n"
                "  dep_libdrm = declare_dependency(\n"
                "    include_directories : include_directories('src/a135f-drm'),\n"
                "    link_args : ['-framework', 'IOKit', '-framework', 'CoreFoundation'],\n"
                "  )\nelif dep_libdrm.found()"))

# 3. Panfrost BO mappings use the A135F user client on Darwin. Mesa 25.0.x
# keeps the generic mmap helper inline in pan_kmod.h and BO unmapping in pan_bo.c.
edit('src/panfrost/lib/kmod/pan_kmod.h', 'bo mmap through the user client',
     r'host_addr = os_mmap\(host_addr, size, prot, flags, bo->dev->fd,\s*mmap_offset \+ bo_offset\);',
     lambda m: ('/* A135F: bo mmap through the user client */\n#ifdef __APPLE__\n'
                '   host_addr = a135f_drm_map(bo->dev->fd, bo->handle, size);\n#else\n'
                '   ' + m.group(0) + '\n#endif\n'))
edit('src/panfrost/lib/kmod/pan_kmod.h', 'mmap failure sentinel',
     r'(if \(host_addr == MAP_FAILED\) \{.*?return )NULL(;\s*\})',
     lambda m: m.group(1) + 'MAP_FAILED /* A135F: mmap failure sentinel */' + m.group(2))
edit('src/gallium/drivers/panfrost/pan_bo.c', 'bo munmap through the user client v2',
     r'   if \(os_munmap\(\(void \*\)\(uintptr_t\)bo->ptr.cpu, panfrost_bo_size\(bo\)\)\) \{\n(.*?)\n   \}',
     lambda m: ('   /* A135F: bo munmap through the user client v2 */\n#ifdef __APPLE__\n'
                '   a135f_drm_unmap(0, 0, (void *)(uintptr_t)bo->ptr.cpu);\n#else\n'
                '   if (os_munmap((void *)(uintptr_t)bo->ptr.cpu, panfrost_bo_size(bo))) {\n'
                + m.group(1) + '\n   }\n#endif'))

# Mali-G52 on Exynos850 is Bifrost/Pan-Arch 7. Do not build unrelated
# Pan-Arch 10 CSF sources or Panthor timeline-sync code on this target.
edit('src/gallium/drivers/panfrost/meson.build', 'limit iOS to Mali-G52 architecture',
     r"panfrost_versions = \['4', '5', '6', '7', '9', '10'\]",
     "# /* A135F: limit iOS to Mali-G52 architecture */\npanfrost_versions = ['4', '5', '6', '7', '9', '10']\nif host_machine.system() == 'darwin'\n  panfrost_versions = ['4', '5', '6', '7', '9']\nendif")

# The A21s Mali-G52 uses Panfrost. Panthor targets newer GPU generations and
# depends on timeline syncobj APIs that the synchronous A135F user client does not need.
edit('src/panfrost/lib/kmod/meson.build', 'exclude Panthor backend on iOS',
     r"  'panthor_kmod.c',",
     lambda m: '# /* A135F: exclude Panthor backend on iOS */ Panfrost on the A21s is the panfrost backend')
edit('src/panfrost/lib/kmod/pan_kmod.c', 'exclude Panthor registration on iOS',
     r'(extern const struct pan_kmod_ops panfrost_kmod_ops;\s*)extern const struct pan_kmod_ops panthor_kmod_ops;',
     lambda m: m.group(1) + '#ifndef __APPLE__ /* A135F: exclude Panthor registration on iOS */\nextern const struct pan_kmod_ops panthor_kmod_ops;\n#endif')
edit('src/panfrost/lib/kmod/pan_kmod.c', 'exclude Panthor device entry on iOS',
     r"(\{\s*\"panfrost\",\s*&panfrost_kmod_ops,\s*\},\s*)\{\s*\"panthor\",\s*&panthor_kmod_ops,\s*\},",
     lambda m: m.group(1) + '#ifndef __APPLE__ /* A135F: exclude Panthor device entry on iOS */\n   {\n      \"panthor\",\n      &panthor_kmod_ops,\n   },\n#endif')
# Keep GEM close declared in this translation unit even when a system libdrm header
# wins the include search before the A135F shim.
edit('src/panfrost/lib/kmod/pan_kmod.h', 'declare A135F GEM close',
     r'(#include <xf86drm.h>)',
     lambda m: m.group(1) + '\n#ifdef __APPLE__\nextern int drmCloseBufferHandle(int fd, uint32_t handle);\n#endif')
edit('src/c11/time.h', 'use Apple timespec definition',
     r'#ifndef HAVE_STRUCT_TIMESPEC\nstruct timespec',
     '#if !defined(HAVE_STRUCT_TIMESPEC) && !defined(__APPLE__) /* A135F: use Apple timespec definition */\nstruct timespec')
edit('src/util/disk_cache.h', 'include Apple dlfcn declarations',
     r'#ifdef HAVE_DLFCN_H\n#include <dlfcn.h>',
     '#if defined(HAVE_DLFCN_H) || defined(__APPLE__) /* A135F: include Apple dlfcn declarations */\n#include <dlfcn.h>')

# Keep the Panfrost linker dispatch for the older JM architectures, but omit
# the Pan-Arch 10 CSF entry on iOS (this device is Pan-Arch 7).
edit('src/gallium/drivers/panfrost/pan_screen.c', 'disable Pan-Arch 10 dispatch on iOS',
     r'(   else if \(dev->arch == 10\)\n      panfrost_cmdstream_screen_init_v10\(screen\);)',
     lambda m: '#ifndef __APPLE__ /* A135F: disable Pan-Arch 10 dispatch on iOS */\n' + m.group(1) + '\n#else\n   else if (dev->arch == 10)\n      unreachable("Pan-Arch 10 is not enabled on iOS");\n#endif')

# iOS has no DRI XML config service. The A21s uses Pan-Arch 7; these option
# queries are for optional paths and can safely use Mesa's disabled defaults.
edit('src/gallium/drivers/panfrost/pan_screen.c', 'iOS defaults for DRI options',
     r'(   driParseConfigFiles\()',
     lambda m: ('#ifdef __APPLE__ /* A135F: iOS defaults for DRI options */\n'
                '#define driParseConfigFiles(...) ((void)0)\n'
                '#define driQueryOptionb(options, name) false\n'
                '#define driQueryOptioni(options, name) 0\n'
                '#endif\n' + m.group(1)))

# The DRM facade functions are part of OSMesa on iOS; libdrm itself is absent.
edit('src/gallium/targets/osmesa/meson.build', 'compile A135F DRM facade into OSMesa',
     r'(libosmesa = shared_library\()',
     lambda m: ('# /* A135F: compile DRM facade into OSMesa */\nosmesa_sources = files(\'osmesa_target.c\')\n'
                'if host_machine.system() == \'darwin\' and with_gallium_panfrost\n'
                '  osmesa_sources += files(\'../../../a135f-drm/a135f.drm.c\')\n'
                'endif\n\n' + m.group(1)))
edit('src/gallium/targets/osmesa/meson.build', 'set OSMesa install name for iOS',
     r'(link_args : \[ld_args_gc_sections, osmesa_link_args\],)',
     lambda m: "link_args : [ld_args_gc_sections, osmesa_link_args, '-Wl,-install_name,/usr/local/lib/a135f/libOSMesa.8.dylib'],")

edit('src/gallium/targets/osmesa/meson.build', 'use OSMesa source list',
     r'(libosmesa = shared_library\(\s*osmesa_lib_name,\s*)\'osmesa_target.c\'',
     lambda m: '# /* A135F: use OSMesa source list */\n' + m.group(1) + 'osmesa_sources')

# 4. OSMesa's target: the Mali is the screen when there is one.
tgt = 'src/gallium/targets/osmesa/osmesa_target.c'
inc = open(os.path.join(here, 'a135f_osmesa_gpu.inc')).read()
edit(tgt, 'gpu screen code',
     r'(struct pipe_screen \*\s*\n?osmesa_create_screen\s*\(void\))',
     lambda m: '/* A135F: gpu screen code */\n#ifdef __APPLE__\n' + inc + '#endif\n\n' + m.group(1))
edit(tgt, 'gpu screen first',
     r'(osmesa_create_screen\s*\(void\)\s*\{)',
     lambda m: m.group(1) + '\n   /* A135F: gpu screen first */\n#ifdef __APPLE__\n   { struct pipe_screen *gpu = osmesa_create_gpu_screen(); if (gpu) return gpu; }\n#endif')
edit('src/gallium/targets/osmesa/meson.build', 'link panfrost',
     r'(driver_swrast\s*,)',
     lambda m: m.group(1) + " driver_panfrost, dep_libdrm,  # /* A135F: link panfrost */\n    ")

# 5. OSMesa's frontend: glEGLImageTargetTexture2DOES takes an IOSurface ID.
fe = 'src/gallium/frontends/osmesa/osmesa.c'
edit(fe, 'egl image from iosurface',
     r'(global_fscreen->get_egl_image\s*=\s*NULL\s*;)',
     lambda m: '/* A135F: egl image from iosurface */\n      global_fscreen->get_egl_image = osmesa_st_get_egl_image;\n      global_fscreen->validate_egl_image = osmesa_st_validate_egl_image;')
edit(fe, 'egl image helpers',
     r'(^static\s+\w[^\n]*\n[^\n]*\n\{)',   # placed before the first static function
     lambda m: ('/* A135F: egl image helpers */\nextern struct pipe_resource *osmesa_surface_resource(struct pipe_screen *screen, uint32_t surface);\n'
                'static bool osmesa_st_get_egl_image(struct pipe_frontend_screen *fscreen, void *image, struct st_egl_image *out)\n'
                '{ out->texture = osmesa_surface_resource(fscreen->screen, (uint32_t)(uintptr_t)image);\n'
                '  if (!out->texture) return false; out->format = out->texture->format; return true; }\n'
                'static bool osmesa_st_validate_egl_image(struct pipe_frontend_screen *fscreen, void *image) { return true; }\n') + m.group(1), flags=re.S | re.M)

print('\n%d edit(s) missed' % len(failed))
sys.exit(1 if failed else 0)
