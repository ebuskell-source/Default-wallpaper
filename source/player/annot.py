import re,sys
data=open('old-arm64','rb').read()
# __cstring at file offset = vma - 0x100000000 (TEXT segment starts at file 0)
cs_start=0x100001e30; cs_size=0x6da
def cstr(addr):
    off=addr-0x100000000
    end=data.index(b'\0',off)
    return data[off:end].decode('utf8','replace')
lines=open('old-arm64.s').read().splitlines()
pages={}
out=[]
for l in lines:
    m=re.match(r'\s*([0-9a-f]+):\s+(\w+)\s+(.*)',l)
    if m:
        op=m.group(2); args=m.group(3)
        if op=='adrp':
            r,imm=[a.strip() for a in args.split(',')[:2]]
            mm=re.search(r'0x([0-9a-f]+)',args)
            if mm: pages[r]=int(mm.group(1),16)
        elif op=='add' :
            a=[x.strip() for x in args.split(',')]
            if len(a)>=3 and a[1] in pages and a[2].startswith('#'):
                addr=pages[a[1]]+int(a[2][1:],0)
                if cs_start<=addr<cs_start+cs_size:
                    l+='    ; "'+cstr(addr)+'"'
                elif addr>=0x100008000:
                    l+='    ; data %x'%addr
        elif op=='ldr':
            mm=re.search(r'\[(x\d+), #(\d+)\]',args)
            if mm and mm.group(1) in pages:
                addr=pages[mm.group(1)]+int(mm.group(2))
                l+='    ; mem %x'%addr
    out.append(l)
open('old-arm64.ann.s','w').write('\n'.join(out))
