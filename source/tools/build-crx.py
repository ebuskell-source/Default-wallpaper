#!/usr/bin/env python3
"""Packs a Chrome/Edge extension folder as a signed CRX3 file, and writes its update manifest.
   build-crx.py <extension folder> <private key .pem> <out .crx> <crx URL> <updates.xml>"""
import hashlib, io, json, os, struct, sys, zipfile
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import padding

src, pem, out, crx_url, updates = sys.argv[1:6]
key = serialization.load_pem_private_key(open(pem, 'rb').read(), None)
pub = key.public_key().public_bytes(serialization.Encoding.DER, serialization.PublicFormat.SubjectPublicKeyInfo)
crx_id = hashlib.sha256(pub).digest()[:16]
ext_id = ''.join(chr(ord('a') + int(c, 16)) for c in crx_id.hex())
version = json.load(open(os.path.join(src, 'manifest.json')))['version']

buf = io.BytesIO()
with zipfile.ZipFile(buf, 'w', zipfile.ZIP_DEFLATED) as z:
    for name in sorted(os.listdir(src)):
        info = zipfile.ZipInfo(name, date_time=(2026, 1, 1, 0, 0, 0))
        info.compress_type = zipfile.ZIP_DEFLATED
        z.writestr(info, open(os.path.join(src, name), 'rb').read())
archive = buf.getvalue()

def varint(n):
    b = bytearray()
    while True:
        byte = n & 0x7F; n >>= 7
        if n: b.append(byte | 0x80)
        else: b.append(byte); return bytes(b)
def field(num, data): return varint(num << 3 | 2) + varint(len(data)) + data

signed_data = field(1, crx_id)                                   # SignedData { crx_id }
message = b'CRX3 SignedData\x00' + struct.pack('<I', len(signed_data)) + signed_data + archive
signature = key.sign(message, padding.PKCS1v15(), hashes.SHA256())
header = field(2, field(1, pub) + field(2, signature)) + field(10000, signed_data)   # CrxFileHeader
with open(out, 'wb') as f:
    f.write(b'Cr24' + struct.pack('<II', 3, len(header)) + header + archive)

open(updates, 'w').write(
    "<?xml version='1.0' encoding='UTF-8'?>\n"
    "<gupdate xmlns='http://www.google.com/update2/response' protocol='2.0'>\n"
    f"  <app appid='{ext_id}'>\n"
    f"    <updatecheck codebase='{crx_url}' version='{version}' />\n"
    "  </app>\n"
    "</gupdate>\n")
print(ext_id, version, out, os.path.getsize(out), 'bytes')
