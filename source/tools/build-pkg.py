#!/usr/bin/env python3
"""Builds the TLA BootPaper Mac flat package (xar) the same way 5.0 was laid out.
   build-pkg.py <build dir with payload/ and scripts/> <version> <output .pkg>"""
import gzip, hashlib, os, struct, subprocess, sys, time, zlib

build, version, out = sys.argv[1], sys.argv[2], sys.argv[3]
here = os.path.dirname(os.path.abspath(__file__))
payload, scripts = os.path.join(build, 'payload'), os.path.join(build, 'scripts')

def cpio_gz(src):
    names = subprocess.run(['find', '.'], cwd=src, capture_output=True, check=True).stdout.decode().split('\n')
    names = sorted(n for n in names if n)
    raw = subprocess.run(['cpio', '-o', '--quiet', '--format=odc', '-R', '0:80'], cwd=src,
                         input=('\n'.join(names) + '\n').encode(), capture_output=True, check=True).stdout
    return gzip.compress(raw, compresslevel=9, mtime=0), len(names)

payload_gz, nfiles = cpio_gz(payload)
scripts_gz, _ = cpio_gz(scripts)
bom_path = os.path.join(build, 'Bom')
subprocess.run([os.path.join(here, 'bomutils/build/bin/mkbom'), '-u', '0', '-g', '80', payload, bom_path], check=True,
               capture_output=True)
bom = open(bom_path, 'rb').read()
kbytes = int(subprocess.run(['du', '-sk', payload], capture_output=True, check=True).stdout.split()[0])

package_info = f'''<?xml version="1.0" encoding="utf-8"?>
<pkg-info overwrite-permissions="true" relocatable="false" identifier="ca.schoolathome.welcomevideo.pkg" postinstall-action="none" version="{version}" format-version="2" generator-version="WelcomeVideo" install-location="/" auth="root">
    <payload numberOfFiles="{nfiles}" installKBytes="{kbytes}"/>
    <bundle path="./Applications/TLA BootPaper.app" id="ca.schoolathome.welcomevideo.app" CFBundleShortVersionString="{version}" CFBundleVersion="{version}"/>
    <bundle-version>
        <bundle id="ca.schoolathome.welcomevideo.app"/>
    </bundle-version>
    <upgrade-bundle>
        <bundle id="ca.schoolathome.welcomevideo.app"/>
    </upgrade-bundle>
    <update-bundle/>
    <atomic-update-bundle/>
    <strict-identifier>
        <bundle id="ca.schoolathome.welcomevideo.app"/>
    </strict-identifier>
    <relocate/>
    <scripts>
        <postinstall file="./postinstall"/>
    </scripts>
</pkg-info>
'''.encode()

distribution = f'''<?xml version="1.0" encoding="utf-8"?>
<installer-gui-script minSpecVersion="2">
    <title>TLA BootPaper</title>
    <options customize="never" require-scripts="false" hostArchitectures="x86_64,arm64"/>
    <domains enable_localSystem="true"/>
    <choices-outline>
        <line choice="default">
            <line choice="ca.schoolathome.welcomevideo.pkg"/>
        </line>
    </choices-outline>
    <choice id="default"/>
    <choice id="ca.schoolathome.welcomevideo.pkg" visible="false">
        <pkg-ref id="ca.schoolathome.welcomevideo.pkg"/>
    </choice>
    <pkg-ref id="ca.schoolathome.welcomevideo.pkg" version="{version}" onConclusion="none" installKBytes="{kbytes}">#welcomevideo.pkg</pkg-ref>
    <pkg-ref id="ca.schoolathome.welcomevideo.pkg">
        <bundle-version>
            <bundle CFBundleShortVersionString="{version}" CFBundleVersion="{version}" id="ca.schoolathome.welcomevideo.app" path="Applications/TLA BootPaper.app"/>
        </bundle-version>
    </pkg-ref>
    <product id="ca.schoolathome.welcomevideo" version="{version}"/>
</installer-gui-script>
'''.encode()

# Heap: the TOC checksum (20 bytes), then Distribution, Scripts, PackageInfo, Bom, Payload.
order = [('Distribution', distribution), ('Scripts', scripts_gz), ('PackageInfo', package_info), ('Bom', bom),
         ('Payload', payload_gz)]
offsets, pos = {}, 20
for name, data in order:
    offsets[name] = pos
    pos += len(data)

now = time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())
def entry(fid, name, data, indent):
    sha = hashlib.sha1(data).hexdigest()
    i = ' ' * indent
    return (f'{i}<file id="{fid}">\n{i} <data>\n{i}  <length>{len(data)}</length>\n'
            f'{i}  <encoding style="application/octet-stream"/>\n{i}  <offset>{offsets[name]}</offset>\n'
            f'{i}  <size>{len(data)}</size>\n{i}  <archived-checksum style="sha1">{sha}</archived-checksum>\n'
            f'{i}  <extracted-checksum style="sha1">{sha}</extracted-checksum>\n{i} </data>\n'
            f'{i} <ctime>{now}</ctime>\n{i} <mtime>{now}</mtime>\n{i} <atime>{now}</atime>\n'
            f'{i} <group>root</group>\n{i} <gid>0</gid>\n{i} <user>root</user>\n{i} <uid>0</uid>\n'
            f'{i} <mode>0644</mode>\n{i} <type>file</type>\n{i} <name>{name}</name>\n{i}</file>\n')
data = dict(order)
toc = ('<?xml version="1.0" encoding="UTF-8"?>\n<xar>\n <toc>\n'
       f'  <creation-time>{now}</creation-time>\n  <checksum style="sha1">\n   <offset>0</offset>\n   <size>20</size>\n  </checksum>\n'
       '  <file id="2">\n'
       f'   <ctime>{now}</ctime>\n   <mtime>{now}</mtime>\n   <atime>{now}</atime>\n'
       '   <group>root</group>\n   <gid>0</gid>\n   <user>root</user>\n   <uid>0</uid>\n   <mode>0755</mode>\n'
       '   <type>directory</type>\n   <name>welcomevideo.pkg</name>\n'
       + entry(3, 'Scripts', data['Scripts'], 3) + entry(4, 'PackageInfo', data['PackageInfo'], 3)
       + entry(5, 'Bom', data['Bom'], 3) + entry(6, 'Payload', data['Payload'], 3)
       + '  </file>\n' + entry(1, 'Distribution', data['Distribution'], 2) + ' </toc>\n</xar>\n').encode()
toc_z = zlib.compress(toc, 9)
with open(out, 'wb') as f:
    f.write(struct.pack('>4sHHQQI', b'xar!', 28, 1, len(toc_z), len(toc), 1))
    f.write(toc_z)
    f.write(hashlib.sha1(toc_z).digest())
    for name, d in order:
        f.write(d)
print(f'{out}: {os.path.getsize(out)} bytes, {nfiles} payload entries, {kbytes} KB installed')
