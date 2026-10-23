#!/usr/bin/env python3
"""On the test machine: new test keys (mktoken.py makes them), and auth.json / keys.json that trust them.
   prep.py <dir to write auth.json and keys.json into>"""
import json, os, sys, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import mktoken as mk
d = sys.argv[1]
os.makedirs(d, exist_ok=True)
cfg = {'required': True, 'provider': 'hub', 'validDays': 30, 'renewDays': 7, 'graceDays': 3, 'remindDays': [7, 3],
       'google': {'clientId': mk.AUD['google'], 'domains': ['schoolathome.ca']},
       'hub': {'signInUrl': 'https://hub.test.schoolathome.ca/bootpaperSignIn', 'issuer': mk.ISS['hub'],
               'jwksUrl': 'https://hub.test.schoolathome.ca/ajax/bootpaperKeys.php'}}
now = int(time.time())
keys = [dict(mk.jwk(k), kind=k, first=now, last=now) for k in ('hub', 'google')]
for k in keys:
    for x in ('kty', 'alg', 'use'): k.pop(x, None)
json.dump(cfg, open(os.path.join(d, 'auth.json'), 'w'))
json.dump({'keys': keys, 'updated': now}, open(os.path.join(d, 'keys.json'), 'w'))
print('ok')
