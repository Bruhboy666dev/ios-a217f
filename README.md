# ios-a217f / ios-a135f

**iOS 16 on Samsung Galaxy A13 (SM-A135F) and Galaxy A21s (SM-A217F)**

## Hardware status

| Area | Device details | State |
| --- | --- | --- |
| Cores | A13 and A21s: 8x Cortex-A55; MPIDR `0x000-3`, `0x100-3`; PSCI | A13 bring-up; A21s profile added |
| Interrupts | A13 and A21s: GIC-400 = **GICv2**; timer INTID 27; MMIO `GICC_IAR` / `GICC_EOIR`; IPIs via `GICD_SGIR` | A13 bring-up; A21s profile added |
| Timer | Both: 26 MHz (ADT `timebase-frequency`) | A13 bring-up; A21s profile added |
| RAM | Both use top bank at `0x880000000`; A21s defaults to the upstream 3 GB profile | A13 bring-up; A21s profile added |
| Display | A13: 1080x2408; A21s: 720x1600 at native mode (a135f_fb_native=1) | A21s native-mode support added |
| Storage | Exynos DWMMC driver; root `rd=mmcroot0` | A13 bring-up; A21s profile added |
| Boot | SBOOT / uniLoader; A21s uses the A21s uniLoader board config | A13 bring-up; A21s image built, not device-tested |
| Keys | Volume up/down on GPIO `gpa0-7` / `gpa1-0`, both pressed together is power | Working |
| power key | power button on PMIC interrupts | not implemented |
| Fuelgauge | Maxim Max1726x | Not implemented |
| Touch | OVT TD4150; embed the matching A13/A21s firmware with mkadt.py --touch-fw | WIP; A21s coordinates use 720x1600 |
| USB | DWC3 USB | Working |
| Display Enable | `DECON_F` (`0x13060000`) + `0x70 = 0x1281`; written by shim and kernel | Working |
| GPU | Mali-G52 | Experimental kernel driver and Panfrost GL userland |
| Audio | ABOX audio | Not implemented |
| Wi-Fi | Samsung S612 | Not implemented |
| Bluetooth | Part of Wi-Fi | Not implemented |
| Modem | Samsung Shannon S5000AP | Not implemented |
| Camera | Samsung Isocell JN1 (S5KJN1) | not implemented |
| Camera | GalaxyCore GC02M1 | Not implemented |
| Camera | GalaxyCore GC08A3 | Not implemented |
| Camera | GalaxyCore GC5035 | Not implemented |
| Camera | GalaxyCore GC02M1_MACRO | Not implemented |
| Main PMIC | Samsung S2MPU12 | Not Implemented |
| Sub PMIC | S2MPB03 | Not implemented |

## How to use it

1. Kernel: run the xnu workflow with machine_config=A217F for A21s or A135F for A13. Download the matching kernel-development-a217f or kernel-development-a135f artifact to xnu/out.
2. For GPU userland, follow userland/BUILD-LINUX.md, then include it while making a root image with tools/ios-create-root-full.sh IPSW --gl userland/out. For an existing mounted HFS root, tools/a135f-root-tweaks.py ROOT --gl userland/out installs the GL files.
3. For A21s, generate the ADT with --device a217f --ram 3gb --touch-fw /path/to/td4150_a21s.bin, then build the shim with BOARD=a217f. Use the A21s controller firmware, not the A13 firmware.
4. Add a135f_fb_native=1 to the A21s boot arguments to select 720x1600; the generated ADT uses 2x scale (360x800 points). Enable a135f_gl=1 only after installing the GL userland into the root.

See docs/PORTING-NOTES.md for the hardware comparison and remaining validation work.

## QEMU Usage
```
export K=/path/to/kernel
mkdir -p out/q
python3 tools/mkadt.py out/q/qemu.adt --qemu
python3 tools/mkpayload.py $K out/q/qemu.adt out/q/payload.bin --cmdline 'debug=0xc serial=3 cpus=1 keepsyms=1 -noprogress'
python3 tools/qemu-a135f.py out/q/payload.bin out/q/run --secs 40 --kernel $K
```

## How to boot it

Use uniLoader to boot. Package the Image under blobs/Image, dtb under blobs/dtb and ramdisk under blobs/ramdisk.

See `docs/PORTING-NOTES.md` for details and the remaining TODO list.
