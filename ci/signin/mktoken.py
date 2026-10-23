#!/usr/bin/env python3
"""Test kit for TLA BootPaper sign-in: a test RSA key (a stand-in for the Hub's or Google's), its JWKS, and tokens.
   mktoken.py jwks                       -> prints the test JWKS
   mktoken.py token <kind> <iat> <nonce> [overrides-json]   -> prints a signed JWT (kind: hub|google)
   mktoken.py nonce <device> <user> <salt>
"""
import base64, hashlib, json, os, sys
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import rsa, padding

HERE = os.path.dirname(os.path.abspath(__file__))
KEYS = {'hub': ('testkey-hub.pem', 'test-hub-1'), 'google': ('testkey-google.pem', 'test-google-1')}
ISS = {'hub': 'https://hub.test.schoolathome.ca', 'google': 'https://accounts.google.com'}
AUD = {'hub': 'tla-bootpaper', 'google': 'test-client.apps.googleusercontent.com'}

def b64u(b): return base64.urlsafe_b64encode(b).rstrip(b'=').decode()

def key(kind):
    path = os.path.join(HERE, KEYS[kind][0])
    if not os.path.exists(path):
        k = rsa.generate_private_key(public_exponent=65537, key_size=2048)
        open(path, 'wb').write(k.private_bytes(serialization.Encoding.PEM, serialization.PrivateFormat.PKCS8,
                                               serialization.NoEncryption()))
    return serialization.load_pem_private_key(open(path, 'rb').read(), None)

def jwk(kind):
    pub = key(kind).public_key().public_numbers()
    n = pub.n.to_bytes((pub.n.bit_length() + 7) // 8, 'big')
    return {'kty': 'RSA', 'alg': 'RS256', 'use': 'sig', 'kid': KEYS[kind][1], 'n': b64u(n),
            'e': b64u(pub.e.to_bytes(3, 'big'))}

def token(kind, iat, nonce, over=None):
    hdr = {'alg': 'RS256', 'typ': 'JWT', 'kid': KEYS[kind][1]}
    if kind == 'hub':
        body = {'iss': ISS[kind], 'aud': AUD[kind], 'sub': '12345', 'username': 'jdoe', 'name': 'Jane Doe',
                'role': 'student', 'iat': iat, 'exp': iat + 600, 'nonce': nonce, 'jti': 'abc'}
    else:
        body = {'iss': ISS[kind], 'aud': AUD[kind], 'azp': AUD[kind], 'sub': '1098', 'hd': 'schoolathome.ca',
                'email': 'jdoe@schoolathome.ca', 'email_verified': True, 'name': 'Jane Doe', 'iat': iat,
                'exp': iat + 3600, 'nonce': nonce}
    over = over or {}
    for k, v in over.get('header', {}).items(): hdr[k] = v
    for k, v in over.items():
        if k in ('header', 'tamper'): continue
        if v is None: body.pop(k, None)
        else: body[k] = v
    si = b64u(json.dumps(hdr, separators=(',', ':')).encode()) + '.' + \
         b64u(json.dumps(body, separators=(',', ':'), ensure_ascii=False).encode())
    sig = key(kind).sign(si.encode(), padding.PKCS1v15(), hashes.SHA256())
    if over.get('tamper'): si = si[:-2] + ('A' if si[-2] != 'A' else 'B') + si[-1]
    return si + '.' + b64u(sig)

def nonce(device, user, salt):
    return b64u(hashlib.sha256(('tla-bootpaper/1\n%s\n%s\n%s' % (device, user, salt)).encode()).digest())

if __name__ == '__main__':
    a = sys.argv[1:]
    if a[0] == 'jwks': print(json.dumps({'keys': [jwk('hub'), jwk('google')]}))
    elif a[0] == 'token': print(token(a[1], int(a[2]), a[3], json.loads(a[4]) if len(a) > 4 else None))
    elif a[0] == 'nonce': print(nonce(a[1], a[2], a[3]))
