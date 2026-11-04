# A21s Metal probe

This is a first-stage Metal bring-up probe for the Mali-G52, not a rendering
driver. It publishes an `IOAcceleratorES` service only when
`a135f_metal_probe=1` is present, loads the bundle below, and records
Metal device/command selectors requested by `backboardd`. The probe
returns stub values, so it may leave the interface incomplete or make the
display unusable. Use only for a diagnostic boot that can be returned to
recovery.

Build:

```sh
userland/metal-probe/build.sh
```

Install into an already mounted HFS root as root; the installer refuses to
overwrite an existing bundle:

```sh
sudo userland/metal-probe/install.sh /path/to/mounted/root
```

For the probe boot, add `a135f_metal_probe=1` and remove
`a135f_gl=1`. The existing boot arguments can otherwise remain.
Look for `A135F Metal probe:` messages in the next iOS log. No log
means service registration, bundle lookup, or code-signing failed before the
device class loaded.

A successful trace only identifies the Metal interface CoreAnimation asks
for. A real renderer still needs command queues/buffers, IOSurface-backed
textures, render/blit encoders, Mali command submission, and translation of
Apple AIR shaders to Mali-G52 instructions.
