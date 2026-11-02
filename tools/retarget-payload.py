#!/usr/bin/env python3
"""Replace the ADT in an existing A135FXNU payload without rebuilding XNU.

This is for board-only changes when the Mach-O kernel segments are unchanged.
The payload header and segment data are preserved; the replacement ADT is
appended and the ADT offset/size fields are updated.
"""
import argparse
import struct

MAGIC = b'A135FXNU'
SEG_TABLE = 0x2A8


def retarget(source, adt_path, output, cmdline=None):
    payload = bytearray(open(source, 'rb').read())
    adt_blob = open(adt_path, 'rb').read()
    if len(payload) < SEG_TABLE or payload[:8] != MAGIC:
        raise SystemExit(f'{source}: not an A135FXNU payload')
    version, nsegs = struct.unpack_from('<II', payload, 8)
    if version != 1 or SEG_TABLE + 32 * nsegs > len(payload):
        raise SystemExit(f'{source}: unsupported or truncated payload header')
    old_adt_off, old_adt_size = struct.unpack_from('<2Q', payload, 0x20)
    if old_adt_off + old_adt_size > len(payload):
        raise SystemExit(f'{source}: ADT points outside the payload')
    if old_adt_off < SEG_TABLE + 32 * nsegs:
        raise SystemExit(f'{source}: ADT overlaps the segment table')
    for i in range(nsegs):
        _, _, file_off, file_size = struct.unpack_from('<4Q', payload, SEG_TABLE + 32 * i)
        if file_off + file_size > old_adt_off:
            raise SystemExit(f'{source}: segment {i} overlaps the ADT')

    # Preserve all existing segment bytes, discarding only the old ADT/trailer.
    payload = payload[:old_adt_off]
    payload.extend(adt_blob)
    payload.extend(b'\0' * (-len(payload) & 0xF))
    struct.pack_into('<2Q', payload, 0x20, old_adt_off, len(adt_blob))
    if cmdline is not None:
        encoded = cmdline.encode()[:607]
        payload[0x48:0x48 + 608] = encoded + b'\0' * (608 - len(encoded))
    with open(output, 'wb') as f:
        f.write(payload)
    print(f'{output}: {len(payload)} bytes; {nsegs} kernel segments; ADT {len(adt_blob)} bytes')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('payload', help='existing A135FXNU payload')
    parser.add_argument('adt', help='replacement Apple Device Tree')
    parser.add_argument('output', help='new payload path')
    parser.add_argument('--cmdline', help='optional replacement XNU boot arguments')
    args = parser.parse_args()
    retarget(args.payload, args.adt, args.output, args.cmdline)
