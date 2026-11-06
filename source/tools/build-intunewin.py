#!/usr/bin/env python3
"""Builds a Win32 .intunewin from a folder, the way IntuneWinAppUtil does (and like the 5.0 package):
   build-intunewin.py <source folder> <setup file> <template Detection.xml> <output .intunewin>"""
import base64, hashlib, hmac, io, os, re, sys, zipfile
from cryptography.hazmat.primitives import padding
from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
src, setup, template, out = sys.argv[1:5]
buf = io.BytesIO()
with zipfile.ZipFile(buf, 'w', zipfile.ZIP_DEFLATED) as z:
    for name in sorted(os.listdir(src)):
        z.write(os.path.join(src, name), name)
plain = buf.getvalue()
key, mac_key, iv = os.urandom(32), os.urandom(32), os.urandom(16)
p = padding.PKCS7(128).padder(); padded = p.update(plain) + p.finalize()
enc = Cipher(algorithms.AES(key), modes.CBC(iv)).encryptor(); ct = enc.update(padded) + enc.finalize()
mac = hmac.new(mac_key, iv + ct, hashlib.sha256).digest()
blob = mac + iv + ct
b64 = lambda b: base64.b64encode(b).decode()
x = open(template).read()
for tag, val in [('Name', setup), ('SetupFile', setup), ('UnencryptedContentSize', str(len(plain))), ('EncryptionKey', b64(key)),
                 ('MacKey', b64(mac_key)), ('InitializationVector', b64(iv)), ('Mac', b64(mac)), ('FileDigest', b64(hashlib.sha256(plain).digest()))]:
    x, n = re.subn('<%s>.*?</%s>' % (tag, tag), '<%s>%s</%s>' % (tag, val, tag), x)
    assert n == 1, tag
with zipfile.ZipFile(out, 'w', zipfile.ZIP_STORED) as z:
    z.writestr('IntuneWinPackage/Contents/IntunePackage.intunewin', blob)
    z.writestr('IntuneWinPackage/Metadata/Detection.xml', x)
print(out, os.path.getsize(out), 'bytes;', len(zipfile.ZipFile(io.BytesIO(plain)).namelist()), 'files')
