
old-arm64:	file format mach-o arm64

Disassembly of section __TEXT,__text:

0000000100000628 <_main>:
100000628:     	sub	sp, sp, #0x180
10000062c:     	stp	d15, d14, [sp, #0xe0]
100000630:     	stp	d13, d12, [sp, #0xf0]
100000634:     	stp	d11, d10, [sp, #0x100]
100000638:     	stp	d9, d8, [sp, #0x110]
10000063c:     	stp	x28, x27, [sp, #0x120]
100000640:     	stp	x26, x25, [sp, #0x130]
100000644:     	stp	x24, x23, [sp, #0x140]
100000648:     	stp	x22, x21, [sp, #0x150]
10000064c:     	stp	x20, x19, [sp, #0x160]
100000650:     	stp	x29, x30, [sp, #0x170]
100000654:     	add	x29, sp, #0x170
100000658:     	mov	x21, x1
10000065c:     	mov	x22, x0
100000660:     	add	x1, sp, #0x48
100000664:     	mov	w0, #0x6                ; =6
100000668:     	bl	0x100001d7c <dyld_stub_binder+0x100001d7c>
10000066c:     	ldp	d8, d9, [sp, #0x48]
100000670:     	adrp	x0, 0x100001000 <_main+0x9d8>
100000674:     	add	x0, x0, #0xe30
100000678:     	bl	0x100001d94 <dyld_stub_binder+0x100001d94>
10000067c:     	cmp	w22, #0x2
100000680:     	b.lt	0x100000698 <_main+0x70>
100000684:     	mov	x20, x0
100000688:     	ldr	x0, [x21, #0x8]
10000068c:     	mov	w1, #0x4                ; =4
100000690:     	bl	0x100001dac <dyld_stub_binder+0x100001dac>
100000694:     	cbz	w0, 0x1000006d8 <_main+0xb0>
100000698:     	adrp	x0, 0x100001000 <_main+0x9d8>
10000069c:     	add	x0, x0, #0xe42
1000006a0:     	bl	0x100001da0 <dyld_stub_binder+0x100001da0>
1000006a4:     	mov	w0, #0x0                ; =0
1000006a8:     	ldp	x29, x30, [sp, #0x170]
1000006ac:     	ldp	x20, x19, [sp, #0x160]
1000006b0:     	ldp	x22, x21, [sp, #0x150]
1000006b4:     	ldp	x24, x23, [sp, #0x140]
1000006b8:     	ldp	x26, x25, [sp, #0x130]
1000006bc:     	ldp	x28, x27, [sp, #0x120]
1000006c0:     	ldp	d9, d8, [sp, #0x110]
1000006c4:     	ldp	d11, d10, [sp, #0x100]
1000006c8:     	ldp	d13, d12, [sp, #0xf0]
1000006cc:     	ldp	d15, d14, [sp, #0xe0]
1000006d0:     	add	sp, sp, #0x180
1000006d4:     	ret
1000006d8:     	cmp	w22, #0x2
1000006dc:     	b.ne	0x1000006f0 <_main+0xc8>
1000006e0:     	mov	w23, #0x0               ; =0
1000006e4:     	mov	x8, #0x404e000000000000 ; =4633641066610819072
1000006e8:     	fmov	d0, x8
1000006ec:     	b	0x10000072c <_main+0x104>
1000006f0:     	ldr	x8, [x21, #0x10]
1000006f4:     	ldrb	w9, [x8]
1000006f8:     	cmp	w9, #0x31
1000006fc:     	b.ne	0x100000718 <_main+0xf0>
100000700:     	ldrb	w8, [x8, #0x1]
100000704:     	cmp	w8, #0x0
100000708:     	cset	w23, eq
10000070c:     	cmp	w22, #0x4
100000710:     	b.hs	0x100000724 <_main+0xfc>
100000714:     	b	0x1000006e4 <_main+0xbc>
100000718:     	mov	w23, #0x0               ; =0
10000071c:     	cmp	w22, #0x4
100000720:     	b.lo	0x1000006e4 <_main+0xbc>
100000724:     	ldr	x0, [x21, #0x18]
100000728:     	bl	0x100001d70 <dyld_stub_binder+0x100001d70>
10000072c:     	fmov	d1, #5.00000000
100000730:     	fcmp	d0, d1
100000734:     	fcsel	d12, d1, d0, mi
100000738:     	adrp	x0, 0x100001000 <_main+0x9d8>
10000073c:     	add	x0, x0, #0xe57
100000740:     	mov	w1, #0x2                ; =2
100000744:     	bl	0x100001d58 <dyld_stub_binder+0x100001d58>
100000748:     	cbz	x0, 0x100000ccc <_main+0x6a4>
10000074c:     	mov	x19, x0
100000750:     	adrp	x0, 0x100001000 <_main+0x9d8>
100000754:     	add	x0, x0, #0xe70
100000758:     	mov	w1, #0x2                ; =2
10000075c:     	bl	0x100001d58 <dyld_stub_binder+0x100001d58>
100000760:     	cbz	x0, 0x100000ccc <_main+0x6a4>
100000764:     	stp	w23, w22, [sp, #0x18]
100000768:     	stp	x21, x20, [sp, #0x20]
10000076c:     	adrp	x1, 0x100001000 <_main+0x9d8>
100000770:     	add	x1, x1, #0xeb1
100000774:     	mov	x0, x19
100000778:     	bl	0x100001d64 <dyld_stub_binder+0x100001d64>
10000077c:     	adrp	x28, 0x100008000 <dyld_stub_binder+0x100008000>
100000780:     	str	x0, [x28, #0x48]
100000784:     	adrp	x1, 0x100001000 <_main+0x9d8>
100000788:     	add	x1, x1, #0xebf
10000078c:     	mov	x0, x19
100000790:     	bl	0x100001d64 <dyld_stub_binder+0x100001d64>
100000794:     	adrp	x25, 0x100008000 <dyld_stub_binder+0x100008000>
100000798:     	str	x0, [x25, #0x50]
10000079c:     	adrp	x1, 0x100001000 <_main+0x9d8>
1000007a0:     	add	x1, x1, #0xed0
1000007a4:     	mov	x0, x19
1000007a8:     	bl	0x100001d64 <dyld_stub_binder+0x100001d64>
1000007ac:     	adrp	x22, 0x100008000 <dyld_stub_binder+0x100008000>
1000007b0:     	str	x0, [x22, #0x58]
1000007b4:     	adrp	x1, 0x100001000 <_main+0x9d8>
1000007b8:     	add	x1, x1, #0xee7
1000007bc:     	mov	x0, x19
1000007c0:     	bl	0x100001d64 <dyld_stub_binder+0x100001d64>
1000007c4:     	adrp	x21, 0x100008000 <dyld_stub_binder+0x100008000>
1000007c8:     	str	x0, [x21, #0x60]
1000007cc:     	adrp	x1, 0x100001000 <_main+0x9d8>
1000007d0:     	add	x1, x1, #0xefe
1000007d4:     	mov	x0, x19
1000007d8:     	bl	0x100001d64 <dyld_stub_binder+0x100001d64>
1000007dc:     	adrp	x23, 0x100008000 <dyld_stub_binder+0x100008000>
1000007e0:     	str	x0, [x23, #0x68]
1000007e4:     	adrp	x1, 0x100001000 <_main+0x9d8>
1000007e8:     	add	x1, x1, #0xf0e
1000007ec:     	mov	x0, x19
1000007f0:     	bl	0x100001d64 <dyld_stub_binder+0x100001d64>
1000007f4:     	adrp	x27, 0x100008000 <dyld_stub_binder+0x100008000>
1000007f8:     	str	x0, [x27, #0x70]
1000007fc:     	adrp	x1, 0x100001000 <_main+0x9d8>
100000800:     	add	x1, x1, #0xf1b
100000804:     	mov	x0, x19
100000808:     	bl	0x100001d64 <dyld_stub_binder+0x100001d64>
10000080c:     	adrp	x8, 0x100008000 <dyld_stub_binder+0x100008000>
100000810:     	str	x0, [x8, #0x78]
100000814:     	ldr	x19, [x22, #0x58]
100000818:     	ldr	x8, [x28, #0x48]
10000081c:     	adrp	x0, 0x100001000 <_main+0x9d8>
100000820:     	add	x0, x0, #0xf2e
100000824:     	blr	x8
100000828:     	adrp	x1, 0x100001000 <_main+0x9d8>
10000082c:     	add	x1, x1, #0xf37
100000830:     	mov	x2, #0x0                ; =0
100000834:     	blr	x19
100000838:     	mov	x24, x0
10000083c:     	ldr	x26, [x23, #0x68]
100000840:     	ldr	x8, [x25, #0x50]
100000844:     	adrp	x0, 0x100001000 <_main+0x9d8>
100000848:     	add	x0, x0, #0xf4b
10000084c:     	blr	x8
100000850:     	mov	x1, x0
100000854:     	adrp	x19, 0x100001000 <_main+0x9d8>
100000858:     	add	x19, x19, #0xce0
10000085c:     	adrp	x20, 0x100001000 <_main+0x9d8>
100000860:     	add	x20, x20, #0xf47
100000864:     	mov	x0, x24
100000868:     	mov	x2, x19
10000086c:     	mov	x3, x20
100000870:     	blr	x26
100000874:     	ldr	x26, [x23, #0x68]
100000878:     	ldr	x8, [x25, #0x50]
10000087c:     	adrp	x0, 0x100001000 <_main+0x9d8>
100000880:     	add	x0, x0, #0xf5e
100000884:     	blr	x8
100000888:     	mov	x1, x0
10000088c:     	mov	x0, x24
100000890:     	mov	x2, x19
100000894:     	mov	x3, x20
100000898:     	blr	x26
10000089c:     	ldr	x8, [x21, #0x60]
1000008a0:     	mov	x0, x24
1000008a4:     	blr	x8
1000008a8:     	ldr	x19, [x22, #0x58]
1000008ac:     	ldr	x8, [x28, #0x48]
1000008b0:     	adrp	x0, 0x100001000 <_main+0x9d8>
1000008b4:     	add	x0, x0, #0xf72
1000008b8:     	blr	x8
1000008bc:     	adrp	x1, 0x100001000 <_main+0x9d8>
1000008c0:     	add	x1, x1, #0xf7b
1000008c4:     	mov	x2, #0x0                ; =0
1000008c8:     	blr	x19
1000008cc:     	mov	x20, x0
1000008d0:     	ldr	x19, [x23, #0x68]
1000008d4:     	ldr	x8, [x25, #0x50]
1000008d8:     	adrp	x0, 0x100001000 <_main+0x9d8>
1000008dc:     	add	x0, x0, #0xf89
1000008e0:     	blr	x8
1000008e4:     	mov	x1, x0
1000008e8:     	adrp	x2, 0x100001000 <_main+0x9d8>
1000008ec:     	add	x2, x2, #0xce8
1000008f0:     	adrp	x3, 0x100001000 <_main+0x9d8>
1000008f4:     	add	x3, x3, #0xf8f
1000008f8:     	mov	x0, x20
1000008fc:     	blr	x19
100000900:     	ldr	x8, [x21, #0x60]
100000904:     	str	x20, [sp, #0x10]
100000908:     	mov	x0, x20
10000090c:     	blr	x8
100000910:     	ldr	x8, [x28, #0x48]
100000914:     	adrp	x0, 0x100001000 <_main+0x9d8>
100000918:     	add	x0, x0, #0xf94
10000091c:     	blr	x8
100000920:     	mov	x19, x0
100000924:     	ldr	x20, [x27, #0x70]
100000928:     	ldr	x8, [x25, #0x50]
10000092c:     	adrp	x0, 0x100001000 <_main+0x9d8>
100000930:     	add	x0, x0, #0xfa2
100000934:     	blr	x8
100000938:     	mov	x1, x0
10000093c:     	mov	x0, x19
100000940:     	blr	x20
100000944:     	mov	x22, x0
100000948:     	ldr	x19, [x27, #0x70]
10000094c:     	ldr	x8, [x25, #0x50]
100000950:     	adrp	x0, 0x100001000 <_main+0x9d8>
100000954:     	add	x0, x0, #0xfb4
100000958:     	blr	x8
10000095c:     	mov	x1, x0
100000960:     	mov	x0, x22
100000964:     	mov	w2, #0x1                ; =1
100000968:     	blr	x19
10000096c:     	ldr	x19, [x27, #0x70]
100000970:     	ldr	x8, [x25, #0x50]
100000974:     	adrp	x0, 0x100001000 <_main+0x9d8>
100000978:     	add	x0, x0, #0xfc9
10000097c:     	blr	x8
100000980:     	mov	x1, x0
100000984:     	mov	x0, x22
100000988:     	blr	x19
10000098c:     	ldr	x8, [x28, #0x48]
100000990:     	adrp	x19, 0x100001000 <_main+0x9d8>
100000994:     	add	x19, x19, #0xfd9
100000998:     	mov	x0, x19
10000099c:     	blr	x8
1000009a0:     	mov	x20, x0
1000009a4:     	ldr	x21, [x27, #0x70]
1000009a8:     	ldr	x8, [x25, #0x50]
1000009ac:     	adrp	x0, 0x100001000 <_main+0x9d8>
1000009b0:     	add	x0, x0, #0xfe2
1000009b4:     	blr	x8
1000009b8:     	mov	x1, x0
1000009bc:     	mov	x0, x20
1000009c0:     	blr	x21
1000009c4:     	mov	x26, x0
1000009c8:     	ldr	x8, [x28, #0x48]
1000009cc:     	mov	x0, x19
1000009d0:     	blr	x8
1000009d4:     	mov	x19, x0
1000009d8:     	ldr	x20, [x27, #0x70]
1000009dc:     	ldr	x8, [x25, #0x50]
1000009e0:     	adrp	x0, 0x100001000 <_main+0x9d8>
1000009e4:     	add	x0, x0, #0xfea
1000009e8:     	blr	x8
1000009ec:     	mov	x1, x0
1000009f0:     	mov	x0, x19
1000009f4:     	blr	x20
1000009f8:     	str	x0, [sp, #0x38]
1000009fc:     	ldr	x19, [x27, #0x70]
100000a00:     	ldr	x8, [x25, #0x50]
100000a04:     	adrp	x0, 0x100001000 <_main+0x9d8>
100000a08:     	add	x0, x0, #0xff5
100000a0c:     	blr	x8
100000a10:     	mov	x1, x0
100000a14:     	mov	x0, x26
100000a18:     	blr	x19
100000a1c:     	subs	x8, x0, #0x1
100000a20:     	b.lt	0x1000017ec <_main+0x11c4>
100000a24:     	str	x22, [sp, #0x30]
100000a28:     	str	xzr, [sp, #0x40]
100000a2c:     	mov	x28, #0x0               ; =0
100000a30:     	mov	x9, #0xcd6500000000     ; =225833675390976
100000a34:     	movk	x9, #0x41cd, lsl #48
100000a38:     	scvtf	d0, d9
100000a3c:     	fmov	d1, x9
100000a40:     	scvtf	d2, d8
100000a44:     	fdiv	d0, d0, d1
100000a48:     	mov	w9, #0xf                ; =15
100000a4c:     	cmp	x8, #0xf
100000a50:     	csel	x8, x8, x9, lo
100000a54:     	fadd	d13, d0, d2
100000a58:     	str	x8, [sp, #0x8]
100000a5c:     	add	x19, x8, #0x1
100000a60:     	b	0x100000a74 <_main+0x44c>
100000a64:     	str	x21, [sp, #0x40]
100000a68:     	add	x28, x28, #0x1
100000a6c:     	cmp	x19, x28
100000a70:     	b.eq	0x100000cd8 <_main+0x6b0>
100000a74:     	ldr	x20, [x27, #0x70]
100000a78:     	ldr	x8, [x25, #0x50]
100000a7c:     	adrp	x0, 0x100001000 <_main+0x9d8>
100000a80:     	add	x0, x0, #0xffb
100000a84:     	blr	x8
100000a88:     	mov	x1, x0
100000a8c:     	mov	x0, x26
100000a90:     	mov	x2, x28
100000a94:     	blr	x20
100000a98:     	mov	x20, x0
100000a9c:     	ldr	x21, [x27, #0x70]
100000aa0:     	ldr	x8, [x25, #0x50]
100000aa4:     	adrp	x0, 0x100002000 <dyld_stub_binder+0x100002000>
100000aa8:     	add	x0, x0, #0xa
100000aac:     	blr	x8
100000ab0:     	mov	x1, x0
100000ab4:     	mov	x0, x20
100000ab8:     	blr	x21
100000abc:     	fmov	d8, d0
100000ac0:     	fmov	d9, d1
100000ac4:     	fmov	d10, d2
100000ac8:     	fmov	d11, d3
100000acc:     	ldr	x23, [x27, #0x70]
100000ad0:     	ldr	x8, [x25, #0x50]
100000ad4:     	adrp	x0, 0x100002000 <dyld_stub_binder+0x100002000>
100000ad8:     	add	x0, x0, #0x10
100000adc:     	blr	x8
100000ae0:     	mov	x1, x0
100000ae4:     	mov	x0, x24
100000ae8:     	blr	x23
100000aec:     	mov	x21, x0
100000af0:     	ldr	x8, [x25, #0x50]
100000af4:     	adrp	x0, 0x100002000 <dyld_stub_binder+0x100002000>
100000af8:     	add	x0, x0, #0x16
100000afc:     	blr	x8
100000b00:     	mov	x1, x0
100000b04:     	mov	x0, x21
100000b08:     	fmov	d0, d8
100000b0c:     	fmov	d1, d9
100000b10:     	fmov	d2, d10
100000b14:     	fmov	d3, d11
100000b18:     	mov	x2, #0x0                ; =0
100000b1c:     	mov	w3, #0x2                ; =2
100000b20:     	mov	w4, #0x0                ; =0
100000b24:     	blr	x23
100000b28:     	mov	x21, x0
100000b2c:     	ldr	x23, [x27, #0x70]
100000b30:     	ldr	x8, [x25, #0x50]
100000b34:     	adrp	x0, 0x100002000 <dyld_stub_binder+0x100002000>
100000b38:     	add	x0, x0, #0x43
100000b3c:     	blr	x8
100000b40:     	mov	x1, x0
100000b44:     	mov	x0, x21
100000b48:     	fmov	d0, d8
100000b4c:     	fmov	d1, d9
100000b50:     	fmov	d2, d10
100000b54:     	fmov	d3, d11
100000b58:     	mov	w2, #0x1                ; =1
100000b5c:     	blr	x23
100000b60:     	adrp	x8, 0x100008000 <dyld_stub_binder+0x100008000>
100000b64:     	ldr	x8, [x8, #0x48]
100000b68:     	adrp	x0, 0x100002000 <dyld_stub_binder+0x100002000>
100000b6c:     	add	x0, x0, #0x69
100000b70:     	blr	x8
100000b74:     	mov	x23, x0
100000b78:     	ldr	x22, [x27, #0x70]
100000b7c:     	ldr	x8, [x25, #0x50]
100000b80:     	adrp	x0, 0x100002000 <dyld_stub_binder+0x100002000>
100000b84:     	add	x0, x0, #0x71
100000b88:     	blr	x8
100000b8c:     	mov	x1, x0
100000b90:     	mov	x0, x23
100000b94:     	blr	x22
100000b98:     	mov	x23, x0
100000b9c:     	ldr	x22, [x27, #0x70]
100000ba0:     	ldr	x8, [x25, #0x50]
100000ba4:     	adrp	x0, 0x100002000 <dyld_stub_binder+0x100002000>
100000ba8:     	add	x0, x0, #0x55
100000bac:     	blr	x8
100000bb0:     	mov	x1, x0
100000bb4:     	mov	x0, x21
100000bb8:     	mov	x2, x23
100000bbc:     	blr	x22
100000bc0:     	ldr	x22, [x27, #0x70]
100000bc4:     	ldr	x8, [x25, #0x50]
100000bc8:     	adrp	x0, 0x100002000 <dyld_stub_binder+0x100002000>
100000bcc:     	add	x0, x0, #0x7c
100000bd0:     	blr	x8
100000bd4:     	mov	x1, x0
100000bd8:     	mov	x0, x21
100000bdc:     	mov	w2, #0x1                ; =1
100000be0:     	blr	x22
100000be4:     	ldr	x22, [x27, #0x70]
100000be8:     	ldr	x8, [x25, #0x50]
100000bec:     	adrp	x0, 0x100002000 <dyld_stub_binder+0x100002000>
100000bf0:     	add	x0, x0, #0x87
100000bf4:     	blr	x8
100000bf8:     	mov	x1, x0
100000bfc:     	mov	x0, x21
100000c00:     	mov	w2, #0x3e8              ; =1000
100000c04:     	blr	x22
100000c08:     	ldr	x22, [x27, #0x70]
100000c0c:     	ldr	x8, [x25, #0x50]
100000c10:     	adrp	x0, 0x100002000 <dyld_stub_binder+0x100002000>
100000c14:     	add	x0, x0, #0x91
100000c18:     	blr	x8
100000c1c:     	mov	x1, x0
100000c20:     	mov	x0, x21
100000c24:     	mov	w2, #0x11               ; =17
100000c28:     	blr	x22
100000c2c:     	ldr	x22, [x27, #0x70]
100000c30:     	ldr	x8, [x25, #0x50]
100000c34:     	adrp	x0, 0x100002000 <dyld_stub_binder+0x100002000>
100000c38:     	add	x0, x0, #0xa8
100000c3c:     	blr	x8
100000c40:     	mov	x1, x0
100000c44:     	mov	x0, x21
100000c48:     	mov	w2, #0x0                ; =0
100000c4c:     	blr	x22
100000c50:     	ldr	x22, [x27, #0x70]
100000c54:     	ldr	x8, [x25, #0x50]
100000c58:     	adrp	x0, 0x100002000 <dyld_stub_binder+0x100002000>
100000c5c:     	add	x0, x0, #0xbf
100000c60:     	blr	x8
100000c64:     	mov	x1, x0
100000c68:     	mov	x0, x21
100000c6c:     	blr	x22
100000c70:     	ldr	x22, [x27, #0x70]
100000c74:     	ldr	x8, [x25, #0x50]
100000c78:     	adrp	x0, 0x100002000 <dyld_stub_binder+0x100002000>
100000c7c:     	add	x0, x0, #0xd4
100000c80:     	blr	x8
100000c84:     	mov	x1, x0
100000c88:     	mov	x0, x21
100000c8c:     	blr	x22
100000c90:     	add	x8, sp, #0x48
100000c94:     	str	x21, [x8, x28, lsl #3]
100000c98:     	ldr	x8, [sp, #0x40]
100000c9c:     	cbz	x8, 0x100000a64 <_main+0x43c>
100000ca0:     	ldr	x22, [x27, #0x70]
100000ca4:     	ldr	x8, [x25, #0x50]
100000ca8:     	adrp	x0, 0x100002000 <dyld_stub_binder+0x100002000>
100000cac:     	add	x0, x0, #0xdc
100000cb0:     	blr	x8
100000cb4:     	mov	x1, x0
100000cb8:     	mov	x0, x20
100000cbc:     	ldr	x2, [sp, #0x38]
100000cc0:     	blr	x22
100000cc4:     	cbnz	w0, 0x100000a64 <_main+0x43c>
100000cc8:     	b	0x100000a68 <_main+0x440>
100000ccc:     	adrp	x0, 0x100001000 <_main+0x9d8>
100000cd0:     	add	x0, x0, #0xea3
100000cd4:     	b	0x1000006a0 <_main+0x78>
100000cd8:     	ldr	x8, [sp, #0x40]
100000cdc:     	cbz	x8, 0x1000017ec <_main+0x11c4>
100000ce0:     	ldr	x19, [x27, #0x70]
100000ce4:     	ldr	x8, [x25, #0x50]
100000ce8:     	adrp	x0, 0x100002000 <dyld_stub_binder+0x100002000>
100000cec:     	add	x0, x0, #0xf6
100000cf0:     	blr	x8
100000cf4:     	mov	x1, x0
100000cf8:     	ldr	x24, [sp, #0x30]
100000cfc:     	mov	x0, x24
100000d00:     	mov	w2, #0x1                ; =1
100000d04:     	blr	x19
100000d08:     	adrp	x21, 0x100008000 <dyld_stub_binder+0x100008000>
100000d0c:     	ldr	x8, [x21, #0x48]
100000d10:     	adrp	x0, 0x100002000 <dyld_stub_binder+0x100002000>
100000d14:     	add	x0, x0, #0x111
100000d18:     	blr	x8
100000d1c:     	mov	x19, x0
100000d20:     	ldr	x20, [x27, #0x70]
100000d24:     	ldr	x8, [x25, #0x50]
100000d28:     	adrp	x0, 0x100002000 <dyld_stub_binder+0x100002000>
100000d2c:     	add	x0, x0, #0x11a
100000d30:     	blr	x8
100000d34:     	mov	x1, x0
100000d38:     	mov	x0, x19
100000d3c:     	mov	w2, #0x1                ; =1
100000d40:     	blr	x20
100000d44:     	ldr	x20, [x27, #0x70]
100000d48:     	ldr	x8, [x21, #0x48]
100000d4c:     	adrp	x0, 0x100002000 <dyld_stub_binder+0x100002000>
100000d50:     	add	x0, x0, #0x475
100000d54:     	blr	x8
100000d58:     	mov	x19, x0
100000d5c:     	ldr	x8, [x25, #0x50]
100000d60:     	adrp	x0, 0x100002000 <dyld_stub_binder+0x100002000>
100000d64:     	add	x0, x0, #0x47c
100000d68:     	blr	x8
100000d6c:     	mov	x1, x0
100000d70:     	mov	x8, #0x147b             ; =5243
100000d74:     	movk	x8, #0x47ae, lsl #16
100000d78:     	movk	x8, #0x7ae1, lsl #32
100000d7c:     	movk	x8, #0x3f84, lsl #48
100000d80:     	fmov	d0, x8
100000d84:     	mov	x0, x19
100000d88:     	blr	x20
100000d8c:     	mov	x19, x0
100000d90:     	ldr	x22, [x27, #0x70]
100000d94:     	ldr	x8, [x25, #0x50]
100000d98:     	adrp	x0, 0x100002000 <dyld_stub_binder+0x100002000>
100000d9c:     	add	x0, x0, #0x49a
100000da0:     	blr	x8
100000da4:     	mov	x20, x0
100000da8:     	ldr	x23, [x27, #0x70]
100000dac:     	ldr	x8, [x21, #0x48]
100000db0:     	adrp	x0, 0x100002000 <dyld_stub_binder+0x100002000>
100000db4:     	add	x0, x0, #0x4eb
100000db8:     	blr	x8
100000dbc:     	mov	x21, x0
100000dc0:     	ldr	x8, [x25, #0x50]
100000dc4:     	adrp	x0, 0x100002000 <dyld_stub_binder+0x100002000>
100000dc8:     	add	x0, x0, #0x4f4
100000dcc:     	blr	x8
100000dd0:     	mov	x1, x0
100000dd4:     	adrp	x2, 0x100002000 <dyld_stub_binder+0x100002000>
100000dd8:     	add	x2, x2, #0x4ca
100000ddc:     	mov	x0, x21
100000de0:     	blr	x23
100000de4:     	mov	x4, x0
100000de8:     	mov	x0, x24
100000dec:     	mov	x1, x20
100000df0:     	mov	x2, #-0x1               ; =-1
100000df4:     	mov	x3, x19
100000df8:     	mov	w5, #0x1                ; =1
100000dfc:     	blr	x22
100000e00:     	cbz	x0, 0x100000e2c <_main+0x804>
100000e04:     	mov	x19, x0
100000e08:     	ldr	x20, [x27, #0x70]
100000e0c:     	ldr	x8, [x25, #0x50]
100000e10:     	adrp	x0, 0x100002000 <dyld_stub_binder+0x100002000>
100000e14:     	add	x0, x0, #0x4e0
100000e18:     	blr	x8
100000e1c:     	mov	x1, x0
100000e20:     	mov	x0, x24
100000e24:     	mov	x2, x19
100000e28:     	blr	x20
100000e2c:     	adrp	x9, 0x100004000 <dyld_stub_binder+0x100004000>
100000e30:     	ldr	x9, [x9, #0x8]
100000e34:     	ldr	x8, [sp, #0x28]
100000e38:     	cbz	x8, 0x100000e94 <_main+0x86c>
100000e3c:     	ldr	x19, [x9]
100000e40:     	sub	x1, x29, #0xa8
100000e44:     	mov	w0, #0x6                ; =6
100000e48:     	bl	0x100001d7c <dyld_stub_binder+0x100001d7c>
100000e4c:     	ldp	d0, d1, [x29, #-0xa8]
100000e50:     	scvtf	d0, d0
100000e54:     	scvtf	d1, d1
100000e58:     	mov	x8, #0xcd6500000000     ; =225833675390976
100000e5c:     	movk	x8, #0x41cd, lsl #48
100000e60:     	fmov	d2, x8
100000e64:     	fdiv	d1, d1, d2
100000e68:     	fadd	d0, d1, d0
100000e6c:     	fsub	d0, d0, d13
100000e70:     	mov	x8, #0x400000000000     ; =70368744177664
100000e74:     	movk	x8, #0x408f, lsl #48
100000e78:     	fmov	d1, x8
100000e7c:     	fmul	d0, d0, d1
100000e80:     	str	d0, [sp]
100000e84:     	adrp	x1, 0x100002000 <dyld_stub_binder+0x100002000>
100000e88:     	add	x1, x1, #0x134
100000e8c:     	mov	x0, x19
100000e90:     	bl	0x100001d88 <dyld_stub_binder+0x100001d88>
100000e94:     	adrp	x0, 0x100002000 <dyld_stub_binder+0x100002000>
100000e98:     	add	x0, x0, #0x14b
100000e9c:     	mov	w1, #0x2                ; =2
100000ea0:     	bl	0x100001d58 <dyld_stub_binder+0x100001d58>
100000ea4:     	cbz	x0, 0x100001bf0 <_main+0x15c8>
100000ea8:     	ldr	x19, [x27, #0x70]
100000eac:     	ldr	x8, [x25, #0x50]
100000eb0:     	adrp	x0, 0x100002000 <dyld_stub_binder+0x100002000>
100000eb4:     	add	x0, x0, #0x19e
100000eb8:     	blr	x8
100000ebc:     	mov	x1, x0
100000ec0:     	ldr	x0, [sp, #0x40]
100000ec4:     	blr	x19
100000ec8:     	mov	x26, x0
100000ecc:     	ldr	x19, [x27, #0x70]
100000ed0:     	ldr	x8, [x25, #0x50]
100000ed4:     	adrp	x0, 0x100002000 <dyld_stub_binder+0x100002000>
100000ed8:     	add	x0, x0, #0x1aa
100000edc:     	blr	x8
100000ee0:     	mov	x1, x0
100000ee4:     	mov	x0, x26
100000ee8:     	mov	w2, #0x1                ; =1
100000eec:     	blr	x19
100000ef0:     	adrp	x28, 0x100008000 <dyld_stub_binder+0x100008000>
100000ef4:     	ldr	x8, [x28, #0x48]
100000ef8:     	adrp	x0, 0x100002000 <dyld_stub_binder+0x100002000>
100000efc:     	add	x0, x0, #0x1b9
100000f00:     	blr	x8
100000f04:     	mov	x19, x0
100000f08:     	ldr	x8, [sp, #0x20]
100000f0c:     	ldr	x22, [x8, #0x8]
100000f10:     	ldr	x24, [x27, #0x70]
100000f14:     	ldr	x8, [x28, #0x48]
100000f18:     	adrp	x20, 0x100002000 <dyld_stub_binder+0x100002000>
100000f1c:     	add	x20, x20, #0x4eb
100000f20:     	mov	x0, x20
100000f24:     	blr	x8
100000f28:     	mov	x23, x0
100000f2c:     	ldr	x8, [x25, #0x50]
100000f30:     	adrp	x21, 0x100002000 <dyld_stub_binder+0x100002000>
100000f34:     	add	x21, x21, #0x4f4
100000f38:     	mov	x0, x21
100000f3c:     	blr	x8
100000f40:     	mov	x1, x0
100000f44:     	mov	x0, x23
100000f48:     	mov	x2, x22
100000f4c:     	blr	x24
100000f50:     	mov	x22, x0
100000f54:     	ldr	x23, [x27, #0x70]
100000f58:     	ldr	x8, [x25, #0x50]
100000f5c:     	adrp	x0, 0x100002000 <dyld_stub_binder+0x100002000>
100000f60:     	add	x0, x0, #0x1bf
100000f64:     	blr	x8
100000f68:     	mov	x1, x0
100000f6c:     	mov	x0, x19
100000f70:     	mov	x2, x22
100000f74:     	blr	x23
100000f78:     	mov	x19, x0
100000f7c:     	ldr	x8, [x28, #0x48]
100000f80:     	adrp	x0, 0x100002000 <dyld_stub_binder+0x100002000>
100000f84:     	add	x0, x0, #0x1d0
100000f88:     	blr	x8
100000f8c:     	mov	x22, x0
100000f90:     	ldr	x23, [x27, #0x70]
100000f94:     	ldr	x8, [x25, #0x50]
100000f98:     	adrp	x0, 0x100002000 <dyld_stub_binder+0x100002000>
100000f9c:     	add	x0, x0, #0x1d9
100000fa0:     	blr	x8
100000fa4:     	mov	x1, x0
100000fa8:     	mov	x0, x22
100000fac:     	mov	x2, x19
100000fb0:     	blr	x23
100000fb4:     	mov	x24, x0
100000fb8:     	ldr	x8, [x28, #0x48]
100000fbc:     	adrp	x0, 0x100002000 <dyld_stub_binder+0x100002000>
100000fc0:     	add	x0, x0, #0x1e8
100000fc4:     	blr	x8
100000fc8:     	mov	x19, x0
100000fcc:     	ldr	x22, [x27, #0x70]
100000fd0:     	ldr	x8, [x25, #0x50]
100000fd4:     	adrp	x0, 0x100002000 <dyld_stub_binder+0x100002000>
100000fd8:     	add	x0, x0, #0x1f6
100000fdc:     	blr	x8
100000fe0:     	mov	x1, x0
100000fe4:     	mov	x0, x19
100000fe8:     	mov	x2, x24
100000fec:     	blr	x22
100000ff0:     	mov	x19, x0
100000ff4:     	ldr	x22, [x27, #0x70]
100000ff8:     	ldr	x8, [x28, #0x48]
100000ffc:     	mov	x0, x20
100001000:     	blr	x8
100001004:     	mov	x20, x0
100001008:     	ldr	x8, [x25, #0x50]
10000100c:     	mov	x0, x21
100001010:     	blr	x8
100001014:     	mov	x1, x0
100001018:     	adrp	x2, 0x100002000 <dyld_stub_binder+0x100002000>
10000101c:     	add	x2, x2, #0x21e
100001020:     	mov	x0, x20
100001024:     	blr	x22
100001028:     	mov	x20, x0
10000102c:     	ldr	x21, [x27, #0x70]
100001030:     	ldr	x8, [x25, #0x50]
100001034:     	adrp	x0, 0x100002000 <dyld_stub_binder+0x100002000>
100001038:     	add	x0, x0, #0x20d
10000103c:     	blr	x8
100001040:     	mov	x1, x0
100001044:     	mov	x0, x19
100001048:     	mov	x2, x20
10000104c:     	blr	x21
100001050:     	ldr	x20, [x27, #0x70]
100001054:     	ldr	x8, [x25, #0x50]
100001058:     	adrp	x0, 0x100002000 <dyld_stub_binder+0x100002000>
10000105c:     	add	x0, x0, #0x23e
100001060:     	blr	x8
100001064:     	mov	x1, x0
100001068:     	mov	x0, x26
10000106c:     	blr	x20
100001070:     	fmov	d10, d0
100001074:     	fmov	d11, d1
100001078:     	fmov	d9, d2
10000107c:     	fmov	d8, d3
100001080:     	ldr	x20, [x27, #0x70]
100001084:     	ldr	x8, [x25, #0x50]
100001088:     	adrp	x0, 0x100002000 <dyld_stub_binder+0x100002000>
10000108c:     	add	x0, x0, #0x245
100001090:     	blr	x8
100001094:     	mov	x1, x0
100001098:     	mov	x0, x19
10000109c:     	fmov	d0, d10
1000010a0:     	fmov	d1, d11
1000010a4:     	fmov	d2, d9
1000010a8:     	fmov	d3, d8
1000010ac:     	blr	x20
1000010b0:     	ldr	x20, [x27, #0x70]
1000010b4:     	ldr	x8, [x25, #0x50]
1000010b8:     	adrp	x0, 0x100002000 <dyld_stub_binder+0x100002000>
1000010bc:     	add	x0, x0, #0x24f
1000010c0:     	blr	x8
1000010c4:     	mov	x1, x0
1000010c8:     	mov	x0, x19
1000010cc:     	mov	w2, #0x12               ; =18
1000010d0:     	blr	x20
1000010d4:     	ldr	x20, [x27, #0x70]
1000010d8:     	ldr	x8, [x25, #0x50]
1000010dc:     	adrp	x0, 0x100002000 <dyld_stub_binder+0x100002000>
1000010e0:     	add	x0, x0, #0x264
1000010e4:     	blr	x8
1000010e8:     	mov	x1, x0
1000010ec:     	mov	x0, x26
1000010f0:     	blr	x20
1000010f4:     	mov	x20, x0
1000010f8:     	ldr	x21, [x27, #0x70]
1000010fc:     	ldr	x8, [x25, #0x50]
100001100:     	adrp	x0, 0x100002000 <dyld_stub_binder+0x100002000>
100001104:     	add	x0, x0, #0x26a
100001108:     	blr	x8
10000110c:     	mov	x1, x0
100001110:     	mov	x0, x20
100001114:     	mov	x2, x19
100001118:     	blr	x21
10000111c:     	str	x24, [sp, #0x38]
100001120:     	ldr	w8, [sp, #0x18]
100001124:     	cbz	w8, 0x100001420 <_main+0xdf8>
100001128:     	ldr	x21, [x27, #0x70]
10000112c:     	adrp	x24, 0x100008000 <dyld_stub_binder+0x100008000>
100001130:     	ldr	x8, [x24, #0x48]
100001134:     	adrp	x0, 0x100002000 <dyld_stub_binder+0x100002000>
100001138:     	add	x0, x0, #0x277
10000113c:     	blr	x8
100001140:     	mov	x19, x0
100001144:     	ldr	x22, [x27, #0x70]
100001148:     	ldr	x8, [x25, #0x50]
10000114c:     	adrp	x20, 0x100002000 <dyld_stub_binder+0x100002000>
100001150:     	add	x20, x20, #0x10
100001154:     	mov	x0, x20
100001158:     	blr	x8
10000115c:     	mov	x1, x0
100001160:     	mov	x0, x19
100001164:     	blr	x22
100001168:     	mov	x19, x0
10000116c:     	ldr	x8, [x25, #0x50]
100001170:     	adrp	x0, 0x100002000 <dyld_stub_binder+0x100002000>
100001174:     	add	x0, x0, #0x280
100001178:     	blr	x8
10000117c:     	mov	x1, x0
100001180:     	mov	x8, #0x800000000000     ; =140737488355328
100001184:     	movk	x8, #0x405b, lsl #48
100001188:     	fmov	d2, x8
10000118c:     	mov	x8, #0x4042000000000000 ; =4630263366890291200
100001190:     	fmov	d3, x8
100001194:     	movi	d0, #0000000000000000
100001198:     	movi	d1, #0000000000000000
10000119c:     	mov	x0, x19
1000011a0:     	blr	x21
1000011a4:     	mov	x19, x0
1000011a8:     	ldr	x28, [x27, #0x70]
1000011ac:     	ldr	x8, [x24, #0x48]
1000011b0:     	adrp	x21, 0x100002000 <dyld_stub_binder+0x100002000>
1000011b4:     	add	x21, x21, #0x4eb
1000011b8:     	mov	x0, x21
1000011bc:     	blr	x8
1000011c0:     	mov	x23, x0
1000011c4:     	ldr	x8, [x25, #0x50]
1000011c8:     	adrp	x22, 0x100002000 <dyld_stub_binder+0x100002000>
1000011cc:     	add	x22, x22, #0x4f4
1000011d0:     	mov	x0, x22
1000011d4:     	blr	x8
1000011d8:     	mov	x1, x0
1000011dc:     	adrp	x2, 0x100002000 <dyld_stub_binder+0x100002000>
1000011e0:     	add	x2, x2, #0x299
1000011e4:     	mov	x0, x23
1000011e8:     	blr	x28
1000011ec:     	mov	x23, x0
1000011f0:     	ldr	x28, [x27, #0x70]
1000011f4:     	ldr	x8, [x25, #0x50]
1000011f8:     	adrp	x0, 0x100002000 <dyld_stub_binder+0x100002000>
1000011fc:     	add	x0, x0, #0x28f
100001200:     	blr	x8
100001204:     	mov	x1, x0
100001208:     	mov	x0, x19
10000120c:     	mov	x2, x23
100001210:     	blr	x28
100001214:     	ldr	x23, [x27, #0x70]
100001218:     	ldr	x8, [x25, #0x50]
10000121c:     	adrp	x0, 0x100002000 <dyld_stub_binder+0x100002000>
100001220:     	add	x0, x0, #0x29e
100001224:     	blr	x8
100001228:     	mov	x1, x0
10000122c:     	mov	x0, x19
100001230:     	mov	w2, #0x1                ; =1
100001234:     	blr	x23
100001238:     	ldr	x23, [x27, #0x70]
10000123c:     	ldr	x8, [x25, #0x50]
100001240:     	adrp	x0, 0x100002000 <dyld_stub_binder+0x100002000>
100001244:     	add	x0, x0, #0x2ad
100001248:     	blr	x8
10000124c:     	mov	x1, x0
100001250:     	mov	x0, x19
100001254:     	mov	w2, #0x3                ; =3
100001258:     	blr	x23
10000125c:     	ldr	x23, [x27, #0x70]
100001260:     	ldr	x8, [x24, #0x48]
100001264:     	ldr	x24, [sp, #0x38]
100001268:     	mov	x0, x21
10000126c:     	blr	x8
100001270:     	mov	x21, x0
100001274:     	ldr	x8, [x25, #0x50]
100001278:     	mov	x0, x22
10000127c:     	blr	x8
100001280:     	mov	x1, x0
100001284:     	adrp	x2, 0x100002000 <dyld_stub_binder+0x100002000>
100001288:     	add	x2, x2, #0x2cf
10000128c:     	mov	x0, x21
100001290:     	blr	x23
100001294:     	mov	x21, x0
100001298:     	ldr	x22, [x27, #0x70]
10000129c:     	ldr	x8, [x25, #0x50]
1000012a0:     	adrp	x0, 0x100002000 <dyld_stub_binder+0x100002000>
1000012a4:     	add	x0, x0, #0x2bd
1000012a8:     	blr	x8
1000012ac:     	mov	x1, x0
1000012b0:     	mov	x0, x19
1000012b4:     	mov	x2, x21
1000012b8:     	blr	x22
1000012bc:     	ldr	x21, [x27, #0x70]
1000012c0:     	ldr	x8, [x25, #0x50]
1000012c4:     	adrp	x0, 0x100002000 <dyld_stub_binder+0x100002000>
1000012c8:     	add	x0, x0, #0x2d1
1000012cc:     	blr	x8
1000012d0:     	mov	x1, x0
1000012d4:     	mov	x0, x19
1000012d8:     	blr	x21
1000012dc:     	ldr	x21, [x27, #0x70]
1000012e0:     	ldr	x8, [x25, #0x50]
1000012e4:     	adrp	x0, 0x100002000 <dyld_stub_binder+0x100002000>
1000012e8:     	add	x0, x0, #0xa
1000012ec:     	blr	x8
1000012f0:     	mov	x1, x0
1000012f4:     	mov	x0, x19
1000012f8:     	blr	x21
1000012fc:     	fsub	d0, d9, d2
100001300:     	mov	x8, #-0x3fbc000000000000 ; =-4592545720011063296
100001304:     	fmov	d1, x8
100001308:     	fadd	d10, d0, d1
10000130c:     	ldr	x21, [x27, #0x70]
100001310:     	ldr	x8, [x25, #0x50]
100001314:     	adrp	x0, 0x100002000 <dyld_stub_binder+0x100002000>
100001318:     	add	x0, x0, #0x2db
10000131c:     	blr	x8
100001320:     	mov	x1, x0
100001324:     	mov	x8, #0x4044000000000000 ; =4630826316843712512
100001328:     	fmov	d1, x8
10000132c:     	mov	x0, x19
100001330:     	fmov	d0, d10
100001334:     	blr	x21
100001338:     	ldr	x21, [x27, #0x70]
10000133c:     	ldr	x8, [x25, #0x50]
100001340:     	adrp	x0, 0x100002000 <dyld_stub_binder+0x100002000>
100001344:     	add	x0, x0, #0x24f
100001348:     	blr	x8
10000134c:     	mov	x1, x0
100001350:     	mov	x0, x19
100001354:     	mov	w2, #0x21               ; =33
100001358:     	blr	x21
10000135c:     	ldr	x21, [x27, #0x70]
100001360:     	ldr	x8, [x25, #0x50]
100001364:     	mov	x0, x20
100001368:     	blr	x8
10000136c:     	mov	x1, x0
100001370:     	ldr	x0, [sp, #0x10]
100001374:     	blr	x21
100001378:     	mov	x20, x0
10000137c:     	ldr	x21, [x27, #0x70]
100001380:     	ldr	x8, [x25, #0x50]
100001384:     	adrp	x0, 0x100002000 <dyld_stub_binder+0x100002000>
100001388:     	add	x0, x0, #0x2f6
10000138c:     	blr	x8
100001390:     	mov	x1, x0
100001394:     	mov	x0, x20
100001398:     	blr	x21
10000139c:     	mov	x20, x0
1000013a0:     	ldr	x21, [x27, #0x70]
1000013a4:     	ldr	x8, [x25, #0x50]
1000013a8:     	adrp	x0, 0x100002000 <dyld_stub_binder+0x100002000>
1000013ac:     	add	x0, x0, #0x2eb
1000013b0:     	blr	x8
1000013b4:     	mov	x1, x0
1000013b8:     	mov	x0, x19
1000013bc:     	mov	x2, x20
1000013c0:     	blr	x21
1000013c4:     	ldr	x21, [x27, #0x70]
1000013c8:     	ldr	x8, [x25, #0x50]
1000013cc:     	adrp	x0, 0x100002000 <dyld_stub_binder+0x100002000>
1000013d0:     	add	x0, x0, #0x2fb
1000013d4:     	blr	x8
1000013d8:     	mov	x20, x0
1000013dc:     	ldr	x8, [x25, #0x50]
1000013e0:     	adrp	x0, 0x100001000 <_main+0x9d8>
1000013e4:     	add	x0, x0, #0xf89
1000013e8:     	blr	x8
1000013ec:     	mov	x2, x0
1000013f0:     	mov	x0, x19
1000013f4:     	mov	x1, x20
1000013f8:     	blr	x21
1000013fc:     	ldr	x20, [x27, #0x70]
100001400:     	ldr	x8, [x25, #0x50]
100001404:     	adrp	x0, 0x100002000 <dyld_stub_binder+0x100002000>
100001408:     	add	x0, x0, #0x306
10000140c:     	blr	x8
100001410:     	mov	x1, x0
100001414:     	mov	x0, x26
100001418:     	mov	x2, x19
10000141c:     	blr	x20
100001420:     	ldr	w8, [sp, #0x1c]
100001424:     	cmp	w8, #0x5
100001428:     	b.lt	0x1000017f8 <_main+0x11d0>
10000142c:     	ldr	x20, [sp, #0x20]
100001430:     	ldr	x8, [x20, #0x20]
100001434:     	ldrb	w8, [x8]
100001438:     	cbz	w8, 0x1000017f8 <_main+0x11d0>
10000143c:     	fmov	d0, #19.00000000
100001440:     	fdiv	d0, d8, d0
100001444:     	fmov	d1, #28.00000000
100001448:     	fcmp	d0, d1
10000144c:     	fcsel	d10, d1, d0, mi
100001450:     	adrp	x23, 0x100008000 <dyld_stub_binder+0x100008000>
100001454:     	ldr	x8, [x23, #0x48]
100001458:     	adrp	x0, 0x100002000 <dyld_stub_binder+0x100002000>
10000145c:     	add	x0, x0, #0x312
100001460:     	blr	x8
100001464:     	mov	x19, x0
100001468:     	ldr	x20, [x20, #0x20]
10000146c:     	ldr	x22, [x27, #0x70]
100001470:     	ldr	x8, [x23, #0x48]
100001474:     	adrp	x0, 0x100002000 <dyld_stub_binder+0x100002000>
100001478:     	add	x0, x0, #0x4eb
10000147c:     	blr	x8
100001480:     	mov	x21, x0
100001484:     	ldr	x8, [x25, #0x50]
100001488:     	adrp	x0, 0x100002000 <dyld_stub_binder+0x100002000>
10000148c:     	add	x0, x0, #0x4f4
100001490:     	blr	x8
100001494:     	mov	x1, x0
100001498:     	mov	x0, x21
10000149c:     	mov	x2, x20
1000014a0:     	blr	x22
1000014a4:     	mov	x20, x0
1000014a8:     	ldr	x21, [x27, #0x70]
1000014ac:     	ldr	x8, [x25, #0x50]
1000014b0:     	adrp	x0, 0x100002000 <dyld_stub_binder+0x100002000>
1000014b4:     	add	x0, x0, #0x31e
1000014b8:     	blr	x8
1000014bc:     	mov	x1, x0
1000014c0:     	mov	x0, x19
1000014c4:     	mov	x2, x20
1000014c8:     	blr	x21
1000014cc:     	mov	x21, x0
1000014d0:     	ldr	x20, [x27, #0x70]
1000014d4:     	ldr	x8, [x23, #0x48]
1000014d8:     	adrp	x0, 0x100002000 <dyld_stub_binder+0x100002000>
1000014dc:     	add	x0, x0, #0x338
1000014e0:     	blr	x8
1000014e4:     	mov	x19, x0
1000014e8:     	ldr	x8, [x25, #0x50]
1000014ec:     	adrp	x0, 0x100002000 <dyld_stub_binder+0x100002000>
1000014f0:     	add	x0, x0, #0x33f
1000014f4:     	blr	x8
1000014f8:     	mov	x1, x0
1000014fc:     	mov	x0, x19
100001500:     	fmov	d0, d10
100001504:     	blr	x20
100001508:     	mov	x19, x0
10000150c:     	ldr	x20, [x27, #0x70]
100001510:     	ldr	x8, [x25, #0x50]
100001514:     	adrp	x0, 0x100002000 <dyld_stub_binder+0x100002000>
100001518:     	add	x0, x0, #0x32f
10000151c:     	blr	x8
100001520:     	mov	x1, x0
100001524:     	mov	x0, x21
100001528:     	mov	x2, x19
10000152c:     	blr	x20
100001530:     	ldr	x8, [x23, #0x48]
100001534:     	adrp	x20, 0x100002000 <dyld_stub_binder+0x100002000>
100001538:     	add	x20, x20, #0x69
10000153c:     	mov	x0, x20
100001540:     	blr	x8
100001544:     	mov	x19, x0
100001548:     	ldr	x22, [x27, #0x70]
10000154c:     	ldr	x8, [x25, #0x50]
100001550:     	adrp	x0, 0x100002000 <dyld_stub_binder+0x100002000>
100001554:     	add	x0, x0, #0x363
100001558:     	blr	x8
10000155c:     	mov	x1, x0
100001560:     	mov	x0, x19
100001564:     	blr	x22
100001568:     	mov	x19, x0
10000156c:     	ldr	x22, [x27, #0x70]
100001570:     	ldr	x8, [x25, #0x50]
100001574:     	adrp	x0, 0x100002000 <dyld_stub_binder+0x100002000>
100001578:     	add	x0, x0, #0x355
10000157c:     	blr	x8
100001580:     	mov	x1, x0
100001584:     	mov	x0, x21
100001588:     	mov	x2, x19
10000158c:     	blr	x22
100001590:     	ldr	x19, [x27, #0x70]
100001594:     	ldr	x8, [x25, #0x50]
100001598:     	adrp	x0, 0x100002000 <dyld_stub_binder+0x100002000>
10000159c:     	add	x0, x0, #0x36e
1000015a0:     	blr	x8
1000015a4:     	mov	x1, x0
1000015a8:     	mov	x0, x21
1000015ac:     	mov	w2, #0x2                ; =2
1000015b0:     	blr	x19
1000015b4:     	ldr	x8, [x23, #0x48]
1000015b8:     	adrp	x0, 0x100002000 <dyld_stub_binder+0x100002000>
1000015bc:     	add	x0, x0, #0x37c
1000015c0:     	blr	x8
1000015c4:     	mov	x19, x0
1000015c8:     	ldr	x22, [x27, #0x70]
1000015cc:     	ldr	x8, [x25, #0x50]
1000015d0:     	adrp	x0, 0x100002000 <dyld_stub_binder+0x100002000>
1000015d4:     	add	x0, x0, #0x10
1000015d8:     	blr	x8
1000015dc:     	mov	x1, x0
1000015e0:     	mov	x0, x19
1000015e4:     	blr	x22
1000015e8:     	mov	x19, x0
1000015ec:     	ldr	x22, [x27, #0x70]
1000015f0:     	ldr	x8, [x25, #0x50]
1000015f4:     	adrp	x0, 0x100002000 <dyld_stub_binder+0x100002000>
1000015f8:     	add	x0, x0, #0x2f6
1000015fc:     	blr	x8
100001600:     	mov	x1, x0
100001604:     	mov	x0, x19
100001608:     	blr	x22
10000160c:     	mov	x19, x0
100001610:     	ldr	x22, [x27, #0x70]
100001614:     	ldr	x8, [x23, #0x48]
100001618:     	mov	x0, x20
10000161c:     	blr	x8
100001620:     	mov	x20, x0
100001624:     	ldr	x23, [x27, #0x70]
100001628:     	ldr	x8, [x25, #0x50]
10000162c:     	adrp	x0, 0x100002000 <dyld_stub_binder+0x100002000>
100001630:     	add	x0, x0, #0x71
100001634:     	blr	x8
100001638:     	mov	x1, x0
10000163c:     	mov	x0, x20
100001640:     	blr	x23
100001644:     	mov	x20, x0
100001648:     	ldr	x8, [x25, #0x50]
10000164c:     	adrp	x0, 0x100002000 <dyld_stub_binder+0x100002000>
100001650:     	add	x0, x0, #0x395
100001654:     	blr	x8
100001658:     	mov	x1, x0
10000165c:     	mov	x8, #0x3333333333333333 ; =3689348814741910323
100001660:     	movk	x8, #0x3feb, lsl #48
100001664:     	fmov	d0, x8
100001668:     	mov	x0, x20
10000166c:     	blr	x22
100001670:     	mov	x20, x0
100001674:     	ldr	x22, [x27, #0x70]
100001678:     	ldr	x8, [x25, #0x50]
10000167c:     	adrp	x0, 0x100002000 <dyld_stub_binder+0x100002000>
100001680:     	add	x0, x0, #0x385
100001684:     	blr	x8
100001688:     	mov	x1, x0
10000168c:     	mov	x0, x19
100001690:     	mov	x2, x20
100001694:     	blr	x22
100001698:     	ldr	x20, [x27, #0x70]
10000169c:     	ldr	x8, [x25, #0x50]
1000016a0:     	adrp	x0, 0x100002000 <dyld_stub_binder+0x100002000>
1000016a4:     	add	x0, x0, #0x3ae
1000016a8:     	blr	x8
1000016ac:     	mov	x1, x0
1000016b0:     	fmov	d0, #10.00000000
1000016b4:     	mov	x0, x19
1000016b8:     	blr	x20
1000016bc:     	ldr	x20, [x27, #0x70]
1000016c0:     	ldr	x8, [x25, #0x50]
1000016c4:     	adrp	x0, 0x100002000 <dyld_stub_binder+0x100002000>
1000016c8:     	add	x0, x0, #0x3c3
1000016cc:     	blr	x8
1000016d0:     	mov	x1, x0
1000016d4:     	movi	d0, #0000000000000000
1000016d8:     	fmov	d1, #-2.00000000
1000016dc:     	mov	x0, x19
1000016e0:     	blr	x20
1000016e4:     	ldr	x20, [x27, #0x70]
1000016e8:     	ldr	x8, [x25, #0x50]
1000016ec:     	adrp	x0, 0x100002000 <dyld_stub_binder+0x100002000>
1000016f0:     	add	x0, x0, #0x3d4
1000016f4:     	blr	x8
1000016f8:     	mov	x1, x0
1000016fc:     	mov	x0, x21
100001700:     	mov	x2, x19
100001704:     	blr	x20
100001708:     	fmov	d0, #13.00000000
10000170c:     	mov	x8, #-0x3fac000000000000 ; =-4588042120383692800
100001710:     	fmov	d1, x8
100001714:     	fadd	d9, d9, d1
100001718:     	fmov	d1, #1.50000000
10000171c:     	fmul	d10, d10, d1
100001720:     	ldr	x19, [x27, #0x70]
100001724:     	ldr	x8, [x25, #0x50]
100001728:     	fdiv	d8, d8, d0
10000172c:     	adrp	x0, 0x100002000 <dyld_stub_binder+0x100002000>
100001730:     	add	x0, x0, #0x245
100001734:     	blr	x8
100001738:     	mov	x1, x0
10000173c:     	mov	x8, #0x4044000000000000 ; =4630826316843712512
100001740:     	fmov	d0, x8
100001744:     	mov	x0, x21
100001748:     	fmov	d1, d8
10000174c:     	fmov	d2, d9
100001750:     	fmov	d3, d10
100001754:     	blr	x19
100001758:     	ldr	x19, [x27, #0x70]
10000175c:     	ldr	x8, [x25, #0x50]
100001760:     	adrp	x0, 0x100002000 <dyld_stub_binder+0x100002000>
100001764:     	add	x0, x0, #0x24f
100001768:     	blr	x8
10000176c:     	mov	x1, x0
100001770:     	mov	x0, x21
100001774:     	mov	w2, #0x2                ; =2
100001778:     	blr	x19
10000177c:     	ldr	x19, [x27, #0x70]
100001780:     	ldr	x8, [x25, #0x50]
100001784:     	adrp	x0, 0x100002000 <dyld_stub_binder+0x100002000>
100001788:     	add	x0, x0, #0x1aa
10000178c:     	blr	x8
100001790:     	mov	x1, x0
100001794:     	mov	x0, x21
100001798:     	mov	w2, #0x1                ; =1
10000179c:     	blr	x19
1000017a0:     	ldr	x19, [x27, #0x70]
1000017a4:     	ldr	x8, [x25, #0x50]
1000017a8:     	adrp	x0, 0x100002000 <dyld_stub_binder+0x100002000>
1000017ac:     	add	x0, x0, #0x3df
1000017b0:     	blr	x8
1000017b4:     	mov	x1, x0
1000017b8:     	movi	d0, #0000000000000000
1000017bc:     	mov	x0, x21
1000017c0:     	blr	x19
1000017c4:     	ldr	x19, [x27, #0x70]
1000017c8:     	ldr	x8, [x25, #0x50]
1000017cc:     	adrp	x0, 0x100002000 <dyld_stub_binder+0x100002000>
1000017d0:     	add	x0, x0, #0x306
1000017d4:     	blr	x8
1000017d8:     	mov	x1, x0
1000017dc:     	mov	x0, x26
1000017e0:     	mov	x2, x21
1000017e4:     	blr	x19
1000017e8:     	b	0x1000017fc <_main+0x11d4>
1000017ec:     	adrp	x0, 0x100002000 <dyld_stub_binder+0x100002000>
1000017f0:     	add	x0, x0, #0xe5
1000017f4:     	b	0x1000006a0 <_main+0x78>
1000017f8:     	mov	x21, #0x0               ; =0
1000017fc:     	ldr	x19, [x27, #0x70]
100001800:     	ldr	x8, [x25, #0x50]
100001804:     	adrp	x0, 0x100002000 <dyld_stub_binder+0x100002000>
100001808:     	add	x0, x0, #0x3ee
10000180c:     	blr	x8
100001810:     	mov	x1, x0
100001814:     	ldr	x0, [sp, #0x40]
100001818:     	mov	x2, #0x0                ; =0
10000181c:     	blr	x19
100001820:     	ldr	x19, [x27, #0x70]
100001824:     	ldr	x8, [x25, #0x50]
100001828:     	adrp	x0, 0x100002000 <dyld_stub_binder+0x100002000>
10000182c:     	add	x0, x0, #0xf6
100001830:     	blr	x8
100001834:     	mov	x1, x0
100001838:     	ldr	x0, [sp, #0x30]
10000183c:     	mov	w2, #0x1                ; =1
100001840:     	blr	x19
100001844:     	ldr	x19, [x27, #0x70]
100001848:     	ldr	x8, [x25, #0x50]
10000184c:     	adrp	x0, 0x100002000 <dyld_stub_binder+0x100002000>
100001850:     	add	x0, x0, #0x404
100001854:     	blr	x8
100001858:     	mov	x1, x0
10000185c:     	mov	x0, x24
100001860:     	blr	x19
100001864:     	ldr	x8, [sp, #0x28]
100001868:     	cbz	x8, 0x1000018a4 <_main+0x127c>
10000186c:     	adrp	x8, 0x100004000 <dyld_stub_binder+0x100004000>
100001870:     	ldr	x8, [x8, #0x8]
100001874:     	ldr	x19, [x8]
100001878:     	bl	0x100001c9c <_now>
10000187c:     	fsub	d0, d0, d13
100001880:     	mov	x8, #0x400000000000     ; =70368744177664
100001884:     	movk	x8, #0x408f, lsl #48
100001888:     	fmov	d1, x8
10000188c:     	fmul	d0, d0, d1
100001890:     	str	d0, [sp]
100001894:     	adrp	x1, 0x100002000 <dyld_stub_binder+0x100002000>
100001898:     	add	x1, x1, #0x409
10000189c:     	mov	x0, x19
1000018a0:     	bl	0x100001d88 <dyld_stub_binder+0x100001d88>
1000018a4:     	sub	x1, x29, #0xa8
1000018a8:     	mov	w0, #0x6                ; =6
1000018ac:     	bl	0x100001d7c <dyld_stub_binder+0x100001d7c>
1000018b0:     	ldp	d0, d1, [x29, #-0xa8]
1000018b4:     	adrp	x26, 0x100008000 <dyld_stub_binder+0x100008000>
1000018b8:     	ldr	w8, [x26, #0x80]
1000018bc:     	cbnz	w8, 0x100001c04 <_main+0x15dc>
1000018c0:     	mov	w28, #0x0               ; =0
1000018c4:     	scvtf	d0, d0
1000018c8:     	scvtf	d1, d1
1000018cc:     	mov	x8, #0xcd6500000000     ; =225833675390976
1000018d0:     	movk	x8, #0x41cd, lsl #48
1000018d4:     	fmov	d2, x8
1000018d8:     	mov	x8, #0x1eb8             ; =7864
1000018dc:     	movk	x8, #0xeb85, lsl #16
1000018e0:     	movk	x8, #0xb851, lsl #32
1000018e4:     	movk	x8, #0x3f9e, lsl #48
1000018e8:     	fdiv	d1, d1, d2
1000018ec:     	fmov	d8, x8
1000018f0:     	fadd	d10, d1, d0
1000018f4:     	movi	d13, #0000000000000000
1000018f8:     	fmov	d11, #4.50000000
1000018fc:     	fmov	d14, #1.00000000
100001900:     	fmov	d15, #8.00000000
100001904:     	b	0x100001910 <_main+0x12e8>
100001908:     	ldr	w8, [x26, #0x80]
10000190c:     	cbnz	w8, 0x100001c04 <_main+0x15dc>
100001910:     	ldr	x22, [x27, #0x70]
100001914:     	adrp	x23, 0x100008000 <dyld_stub_binder+0x100008000>
100001918:     	ldr	x8, [x23, #0x48]
10000191c:     	adrp	x0, 0x100002000 <dyld_stub_binder+0x100002000>
100001920:     	add	x0, x0, #0x475
100001924:     	blr	x8
100001928:     	mov	x19, x0
10000192c:     	ldr	x8, [x25, #0x50]
100001930:     	adrp	x0, 0x100002000 <dyld_stub_binder+0x100002000>
100001934:     	add	x0, x0, #0x47c
100001938:     	blr	x8
10000193c:     	mov	x1, x0
100001940:     	mov	x0, x19
100001944:     	fmov	d0, d8
100001948:     	blr	x22
10000194c:     	mov	x19, x0
100001950:     	ldr	x24, [x27, #0x70]
100001954:     	ldr	x8, [x25, #0x50]
100001958:     	adrp	x0, 0x100002000 <dyld_stub_binder+0x100002000>
10000195c:     	add	x0, x0, #0x49a
100001960:     	blr	x8
100001964:     	mov	x22, x0
100001968:     	ldr	x20, [x27, #0x70]
10000196c:     	ldr	x8, [x23, #0x48]
100001970:     	adrp	x0, 0x100002000 <dyld_stub_binder+0x100002000>
100001974:     	add	x0, x0, #0x4eb
100001978:     	blr	x8
10000197c:     	mov	x23, x0
100001980:     	ldr	x8, [x25, #0x50]
100001984:     	adrp	x0, 0x100002000 <dyld_stub_binder+0x100002000>
100001988:     	add	x0, x0, #0x4f4
10000198c:     	blr	x8
100001990:     	mov	x1, x0
100001994:     	mov	x0, x23
100001998:     	adrp	x2, 0x100002000 <dyld_stub_binder+0x100002000>
10000199c:     	add	x2, x2, #0x4ca
1000019a0:     	blr	x20
1000019a4:     	mov	x4, x0
1000019a8:     	ldr	x23, [sp, #0x30]
1000019ac:     	mov	x0, x23
1000019b0:     	mov	x1, x22
1000019b4:     	mov	x2, #-0x1               ; =-1
1000019b8:     	mov	x3, x19
1000019bc:     	mov	w5, #0x1                ; =1
1000019c0:     	blr	x24
1000019c4:     	cbz	x0, 0x1000019f0 <_main+0x13c8>
1000019c8:     	mov	x19, x0
1000019cc:     	ldr	x20, [x27, #0x70]
1000019d0:     	ldr	x8, [x25, #0x50]
1000019d4:     	adrp	x0, 0x100002000 <dyld_stub_binder+0x100002000>
1000019d8:     	add	x0, x0, #0x4e0
1000019dc:     	blr	x8
1000019e0:     	mov	x1, x0
1000019e4:     	mov	x0, x23
1000019e8:     	mov	x2, x19
1000019ec:     	blr	x20
1000019f0:     	ldr	x19, [x27, #0x70]
1000019f4:     	ldr	x8, [x25, #0x50]
1000019f8:     	adrp	x0, 0x100002000 <dyld_stub_binder+0x100002000>
1000019fc:     	add	x0, x0, #0x420
100001a00:     	blr	x8
100001a04:     	mov	x1, x0
100001a08:     	ldr	x24, [sp, #0x38]
100001a0c:     	mov	x0, x24
100001a10:     	blr	x19
100001a14:     	cbz	x0, 0x100001a44 <_main+0x141c>
100001a18:     	mov	x19, x0
100001a1c:     	ldr	x20, [x27, #0x70]
100001a20:     	ldr	x8, [x25, #0x50]
100001a24:     	adrp	x0, 0x100002000 <dyld_stub_binder+0x100002000>
100001a28:     	add	x0, x0, #0x42c
100001a2c:     	blr	x8
100001a30:     	mov	x1, x0
100001a34:     	mov	x0, x19
100001a38:     	blr	x20
100001a3c:     	cmp	x0, #0x2
100001a40:     	b.eq	0x100001bfc <_main+0x15d4>
100001a44:     	ldr	x19, [x27, #0x70]
100001a48:     	ldr	x8, [x25, #0x50]
100001a4c:     	adrp	x0, 0x100002000 <dyld_stub_binder+0x100002000>
100001a50:     	add	x0, x0, #0x433
100001a54:     	blr	x8
100001a58:     	mov	x1, x0
100001a5c:     	mov	x0, x24
100001a60:     	blr	x19
100001a64:     	fcmp	s0, #0.0
100001a68:     	b.le	0x100001aa0 <_main+0x1478>
100001a6c:     	cbnz	w28, 0x100001aac <_main+0x1484>
100001a70:     	sub	x1, x29, #0xa8
100001a74:     	mov	w0, #0x6                ; =6
100001a78:     	bl	0x100001d7c <dyld_stub_binder+0x100001d7c>
100001a7c:     	ldp	d0, d1, [x29, #-0xa8]
100001a80:     	scvtf	d0, d0
100001a84:     	scvtf	d1, d1
100001a88:     	mov	x8, #0xcd6500000000     ; =225833675390976
100001a8c:     	movk	x8, #0x41cd, lsl #48
100001a90:     	fmov	d2, x8
100001a94:     	fdiv	d1, d1, d2
100001a98:     	fadd	d13, d1, d0
100001a9c:     	b	0x100001aac <_main+0x1484>
100001aa0:     	cbz	w28, 0x100001b28 <_main+0x1500>
100001aa4:     	mov	w8, #0x1                ; =1
100001aa8:     	str	w8, [x26, #0x80]
100001aac:     	cbz	x21, 0x100001b98 <_main+0x1570>
100001ab0:     	sub	x1, x29, #0xa8
100001ab4:     	mov	w0, #0x6                ; =6
100001ab8:     	bl	0x100001d7c <dyld_stub_binder+0x100001d7c>
100001abc:     	ldp	d0, d1, [x29, #-0xa8]
100001ac0:     	scvtf	d0, d0
100001ac4:     	scvtf	d1, d1
100001ac8:     	mov	x8, #0xcd6500000000     ; =225833675390976
100001acc:     	movk	x8, #0x41cd, lsl #48
100001ad0:     	fmov	d2, x8
100001ad4:     	fdiv	d1, d1, d2
100001ad8:     	fadd	d0, d1, d0
100001adc:     	fsub	d0, d0, d13
100001ae0:     	movi	d9, #0000000000000000
100001ae4:     	mov	x8, #0x3333333333333333 ; =3689348814741910323
100001ae8:     	movk	x8, #0x3fd3, lsl #48
100001aec:     	fmov	d1, x8
100001af0:     	fcmp	d0, d1
100001af4:     	b.mi	0x100001b74 <_main+0x154c>
100001af8:     	mov	x8, #-0x6666666666666667 ; =-7378697629483820647
100001afc:     	movk	x8, #0x999a
100001b00:     	movk	x8, #0x3fe9, lsl #48
100001b04:     	fmov	d1, x8
100001b08:     	fcmp	d0, d1
100001b0c:     	b.pl	0x100001b30 <_main+0x1508>
100001b10:     	mov	x8, #0x3333333333333333 ; =3689348814741910323
100001b14:     	movk	x8, #0xbfd3, lsl #48
100001b18:     	fmov	d1, x8
100001b1c:     	fadd	d0, d0, d1
100001b20:     	fadd	d9, d0, d0
100001b24:     	b	0x100001b74 <_main+0x154c>
100001b28:     	mov	w19, #0x1               ; =1
100001b2c:     	b	0x100001ba0 <_main+0x1578>
100001b30:     	fmov	d9, #1.00000000
100001b34:     	fcmp	d0, d11
100001b38:     	b.mi	0x100001b74 <_main+0x154c>
100001b3c:     	mov	x8, #-0x3333333333333334 ; =-3689348814741910324
100001b40:     	movk	x8, #0xcccd
100001b44:     	movk	x8, #0x4014, lsl #48
100001b48:     	fmov	d1, x8
100001b4c:     	fcmp	d0, d1
100001b50:     	movi	d9, #0000000000000000
100001b54:     	b.pl	0x100001b74 <_main+0x154c>
100001b58:     	fmov	d1, #-4.50000000
100001b5c:     	fadd	d0, d0, d1
100001b60:     	mov	x8, #0x6666666666666666 ; =7378697629483820646
100001b64:     	movk	x8, #0xbfe6, lsl #48
100001b68:     	fmov	d1, x8
100001b6c:     	fdiv	d0, d0, d1
100001b70:     	fadd	d9, d0, d14
100001b74:     	ldr	x19, [x27, #0x70]
100001b78:     	ldr	x8, [x25, #0x50]
100001b7c:     	adrp	x0, 0x100002000 <dyld_stub_binder+0x100002000>
100001b80:     	add	x0, x0, #0x3df
100001b84:     	blr	x8
100001b88:     	mov	x1, x0
100001b8c:     	mov	x0, x21
100001b90:     	fmov	d0, d9
100001b94:     	blr	x19
100001b98:     	mov	w19, #0x0               ; =0
100001b9c:     	mov	w28, #0x1               ; =1
100001ba0:     	sub	x1, x29, #0xa8
100001ba4:     	mov	w0, #0x6                ; =6
100001ba8:     	bl	0x100001d7c <dyld_stub_binder+0x100001d7c>
100001bac:     	ldp	d0, d1, [x29, #-0xa8]
100001bb0:     	scvtf	d0, d0
100001bb4:     	scvtf	d1, d1
100001bb8:     	mov	x8, #0xcd6500000000     ; =225833675390976
100001bbc:     	movk	x8, #0x41cd, lsl #48
100001bc0:     	fmov	d2, x8
100001bc4:     	fdiv	d1, d1, d2
100001bc8:     	fadd	d0, d1, d0
100001bcc:     	fsub	d0, d0, d10
100001bd0:     	cbz	w19, 0x100001bdc <_main+0x15b4>
100001bd4:     	fcmp	d0, d15
100001bd8:     	b.gt	0x100001bfc <_main+0x15d4>
100001bdc:     	fcmp	d0, d12
100001be0:     	b.le	0x100001908 <_main+0x12e0>
100001be4:     	mov	w8, #0x1                ; =1
100001be8:     	str	w8, [x26, #0x80]
100001bec:     	b	0x100001908 <_main+0x12e0>
100001bf0:     	adrp	x0, 0x100002000 <dyld_stub_binder+0x100002000>
100001bf4:     	add	x0, x0, #0x18a
100001bf8:     	b	0x1000006a0 <_main+0x78>
100001bfc:     	mov	w8, #0x3                ; =3
100001c00:     	str	w8, [x26, #0x80]
100001c04:     	ldr	x19, [x27, #0x70]
100001c08:     	ldr	x8, [x25, #0x50]
100001c0c:     	adrp	x0, 0x100002000 <dyld_stub_binder+0x100002000>
100001c10:     	add	x0, x0, #0x438
100001c14:     	blr	x8
100001c18:     	mov	x1, x0
100001c1c:     	mov	x0, x24
100001c20:     	blr	x19
100001c24:     	ldr	x8, [sp, #0x8]
100001c28:     	add	x21, x8, #0x1
100001c2c:     	add	x22, sp, #0x48
100001c30:     	adrp	x19, 0x100002000 <dyld_stub_binder+0x100002000>
100001c34:     	add	x19, x19, #0x43e
100001c38:     	ldr	x20, [x22], #0x8
100001c3c:     	ldr	x23, [x27, #0x70]
100001c40:     	ldr	x8, [x25, #0x50]
100001c44:     	mov	x0, x19
100001c48:     	blr	x8
100001c4c:     	mov	x1, x0
100001c50:     	mov	x0, x20
100001c54:     	mov	x2, #0x0                ; =0
100001c58:     	blr	x23
100001c5c:     	subs	x21, x21, #0x1
100001c60:     	b.ne	0x100001c38 <_main+0x1610>
100001c64:     	ldr	w8, [x26, #0x80]
100001c68:     	cmp	w8, #0x1
100001c6c:     	b.ne	0x100001c7c <_main+0x1654>
100001c70:     	adrp	x0, 0x100002000 <dyld_stub_binder+0x100002000>
100001c74:     	add	x0, x0, #0x448
100001c78:     	b	0x1000006a0 <_main+0x78>
100001c7c:     	ldr	w8, [x26, #0x80]
100001c80:     	adrp	x9, 0x100002000 <dyld_stub_binder+0x100002000>
100001c84:     	add	x9, x9, #0x457
100001c88:     	adrp	x10, 0x100002000 <dyld_stub_binder+0x100002000>
100001c8c:     	add	x10, x10, #0x44f
100001c90:     	cmp	w8, #0x2
100001c94:     	csel	x0, x10, x9, eq
100001c98:     	b	0x1000006a0 <_main+0x78>

0000000100001c9c <_now>:
100001c9c:     	sub	sp, sp, #0x20
100001ca0:     	stp	x29, x30, [sp, #0x10]
100001ca4:     	add	x29, sp, #0x10
100001ca8:     	mov	x1, sp
100001cac:     	mov	w0, #0x6                ; =6
100001cb0:     	bl	0x100001d7c <dyld_stub_binder+0x100001d7c>
100001cb4:     	ldp	d0, d1, [sp]
100001cb8:     	scvtf	d0, d0
100001cbc:     	scvtf	d1, d1
100001cc0:     	mov	x8, #0xcd6500000000     ; =225833675390976
100001cc4:     	movk	x8, #0x41cd, lsl #48
100001cc8:     	fmov	d2, x8
100001ccc:     	fdiv	d1, d1, d2
100001cd0:     	fadd	d0, d1, d0
100001cd4:     	ldp	x29, x30, [sp, #0x10]
100001cd8:     	add	sp, sp, #0x20
100001cdc:     	ret

0000000100001ce0 <_yes>:
100001ce0:     	mov	w0, #0x1                ; =1
100001ce4:     	ret

0000000100001ce8 <_skip>:
100001ce8:     	mov	w8, #0x2                ; =2
100001cec:     	adrp	x9, 0x100008000 <dyld_stub_binder+0x100008000>
100001cf0:     	str	w8, [x9, #0x80]
100001cf4:     	ret

0000000100001cf8 <_clock_gettime__thunk>:
100001cf8:     	adrp	x16, 0x100001000 <_main+0x9d8>
100001cfc:     	add	x16, x16, #0xd7c
100001d00:     	br	x16

0000000100001d04 <_getenv__thunk>:
100001d04:     	adrp	x16, 0x100001000 <_main+0x9d8>
100001d08:     	add	x16, x16, #0xd94
100001d0c:     	br	x16

0000000100001d10 <_access__thunk>:
100001d10:     	adrp	x16, 0x100001000 <_main+0x9d8>
100001d14:     	add	x16, x16, #0xdac
100001d18:     	br	x16

0000000100001d1c <_puts__thunk>:
100001d1c:     	adrp	x16, 0x100001000 <_main+0x9d8>
100001d20:     	add	x16, x16, #0xda0
100001d24:     	br	x16

0000000100001d28 <_atof__thunk>:
100001d28:     	adrp	x16, 0x100001000 <_main+0x9d8>
100001d2c:     	add	x16, x16, #0xd70
100001d30:     	br	x16

0000000100001d34 <_dlopen__thunk>:
100001d34:     	adrp	x16, 0x100001000 <_main+0x9d8>
100001d38:     	add	x16, x16, #0xd58
100001d3c:     	br	x16

0000000100001d40 <_dlsym__thunk>:
100001d40:     	adrp	x16, 0x100001000 <_main+0x9d8>
100001d44:     	add	x16, x16, #0xd64
100001d48:     	br	x16

0000000100001d4c <_fprintf__thunk>:
100001d4c:     	adrp	x16, 0x100001000 <_main+0x9d8>
100001d50:     	add	x16, x16, #0xd88
100001d54:     	br	x16

Disassembly of section __TEXT,__stubs:

0000000100001d58 <__stubs>:
100001d58:     	adrp	x16, 0x100008000 <dyld_stub_binder+0x100008000>
100001d5c:     	ldr	x16, [x16]
100001d60:     	br	x16
100001d64:     	adrp	x16, 0x100008000 <dyld_stub_binder+0x100008000>
100001d68:     	ldr	x16, [x16, #0x8]
100001d6c:     	br	x16
100001d70:     	adrp	x16, 0x100008000 <dyld_stub_binder+0x100008000>
100001d74:     	ldr	x16, [x16, #0x10]
100001d78:     	br	x16
100001d7c:     	adrp	x16, 0x100008000 <dyld_stub_binder+0x100008000>
100001d80:     	ldr	x16, [x16, #0x18]
100001d84:     	br	x16
100001d88:     	adrp	x16, 0x100008000 <dyld_stub_binder+0x100008000>
100001d8c:     	ldr	x16, [x16, #0x20]
100001d90:     	br	x16
100001d94:     	adrp	x16, 0x100008000 <dyld_stub_binder+0x100008000>
100001d98:     	ldr	x16, [x16, #0x28]
100001d9c:     	br	x16
100001da0:     	adrp	x16, 0x100008000 <dyld_stub_binder+0x100008000>
100001da4:     	ldr	x16, [x16, #0x30]
100001da8:     	br	x16
100001dac:     	adrp	x16, 0x100008000 <dyld_stub_binder+0x100008000>
100001db0:     	ldr	x16, [x16, #0x38]
100001db4:     	br	x16

Disassembly of section __TEXT,__stub_helper:

0000000100001db8 <__stub_helper>:
100001db8:     	adrp	x17, 0x100008000 <dyld_stub_binder+0x100008000>
100001dbc:     	add	x17, x17, #0x40
100001dc0:     	stp	x16, x17, [sp, #-0x10]!
100001dc4:     	adrp	x16, 0x100004000 <dyld_stub_binder+0x100004000>
100001dc8:     	ldr	x16, [x16]
100001dcc:     	br	x16
100001dd0:     	ldr	w16, 0x100001dd8 <__stub_helper+0x20>
100001dd4:     	b	0x100001db8 <__stub_helper>
100001dd8:     	udf	#0x0
100001ddc:     	ldr	w16, 0x100001de4 <__stub_helper+0x2c>
100001de0:     	b	0x100001db8 <__stub_helper>
100001de4:     	udf	#0x0
100001de8:     	ldr	w16, 0x100001df0 <__stub_helper+0x38>
100001dec:     	b	0x100001db8 <__stub_helper>
100001df0:     	udf	#0x0
100001df4:     	ldr	w16, 0x100001dfc <__stub_helper+0x44>
100001df8:     	b	0x100001db8 <__stub_helper>
100001dfc:     	udf	#0x0
100001e00:     	ldr	w16, 0x100001e08 <__stub_helper+0x50>
100001e04:     	b	0x100001db8 <__stub_helper>
100001e08:     	udf	#0x0
100001e0c:     	ldr	w16, 0x100001e14 <__stub_helper+0x5c>
100001e10:     	b	0x100001db8 <__stub_helper>
100001e14:     	udf	#0x0
100001e18:     	ldr	w16, 0x100001e20 <__stub_helper+0x68>
100001e1c:     	b	0x100001db8 <__stub_helper>
100001e20:     	udf	#0x0
100001e24:     	ldr	w16, 0x100001e2c <__stub_helper+0x74>
100001e28:     	b	0x100001db8 <__stub_helper>
100001e2c:     	udf	#0x0
