// player.c - tla-player, the native intro video player on Macs (TLA BootPaper).
//
//   tla-player <video> <skip 0|1> <timeout seconds> [<greeting>] [<greeting style>]
//
// Covers every screen in black straight away (above the menu bar and Dock), plays the video on the main screen and
// prints "played", "skipped" or "error: ...". With skip 1 there's a Skip button (Esc presses it too).
// The greeting ("Good morning, Sam!") shows over the first few seconds. 5.5.5: in the style of the video's theme
// (the style string comes from common.zsh, WV_GREETING_STYLES; the keys are described at parse_style below), drawn
// with Core Animation layers, one per letter, moved every frame.
//
// Only libSystem is linked: the Objective-C runtime, AppKit and AVFoundation are opened at run time, and every
// message is sent through objc_msgSend cast to the exact type of the method (required on arm64).
// Built for both kinds of Mac with zig cc (build-player.sh) and joined into one file with lipo.
// TLA_PLAYER_TIMING=1 prints when the screens were covered and when the video started (to stderr).

#include <dlfcn.h>
#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

typedef void *id;
typedef void *SEL;
typedef void *Class;
typedef signed char BOOL;
typedef struct { double x, y; } Pt;
typedef struct { double w, h; } Sz;
typedef struct { Pt o; Sz s; } Rect;
typedef struct { unsigned long loc, len; } Range;
typedef struct { double a, b, c, d, tx, ty; } Affine;

static Class (*p_getClass)(const char *);
static SEL (*p_sel)(const char *);
static Class (*p_allocPair)(Class, const char *, size_t);
static void (*p_registerPair)(Class);
static BOOL (*p_addMethod)(Class, SEL, void *, const char *);
static void *p_msg, *p_msg_stret;
static void *appkit;

#define S(n) p_sel(n)
#define CLS(n) p_getClass(n)
#define MSG(ret, ...) ((ret (*)(id, SEL, ##__VA_ARGS__))p_msg)
#if defined(__x86_64__)
#define MSG_RECT ((Rect (*)(id, SEL))p_msg_stret)
#else
#define MSG_RECT ((Rect (*)(id, SEL))p_msg)
#endif

static double now(void) {
    struct timespec t;
    clock_gettime(CLOCK_MONOTONIC, &t);
    return (double)t.tv_sec + (double)t.tv_nsec / 1e9;
}

static BOOL yes(id self, SEL cmd) { (void)self; (void)cmd; return 1; }
static volatile int state = 0;   // 0 playing, 1 played (ended or timed out), 2 skipped, 3 failed
static void skip(id self, SEL cmd, id sender) { (void)self; (void)cmd; (void)sender; state = 2; }

static id nsstr(const char *s) { return MSG(id, const char *)(CLS("NSString"), S("stringWithUTF8String:"), s ? s : ""); }

// ---- The greeting's style -----------------------------------------------------------------------------------------
// "key=value;key=value". Anything left out keeps the classic look (white, a soft shadow, fading in and out).
//   a    how it comes in: line (all of it at once), seq (one letter after another), rand (letters in a random order)
//   t0   seconds after the video starts   st  seconds between letters   d  seconds each letter takes
//   e    easing: lin, out, back (overshoots), bounce, elastic, step (appears at once)
//   dx dy  where it starts from, in font sizes (dy up)   sc sx sy  starting size (all, across, up)   r  starting turn
//   al   starting opacity   an  c (turn and grow around the middle) or b (around the bottom)
//   bob  keeps bobbing by this much (font sizes)   bp  seconds per bob
//   f    font: sys, round, mono, serif   w  semibold, bold, heavy   it  1 for italic   sz  size (1 = normal)
//   c    colour(s) RRGGBB[AA], cycling through the letters   gl  glow RRGGBB[AA]:radius   sh  shadow RRGGBB[AA]:blur:dx:dy
//   p    a panel behind it: glass, term   pre  text before the greeting   cur  a blinking cursor after it
//   ls   extra space between letters   h  when it starts going (seconds)   xd  how long that takes   x  fade, step, drop
typedef struct {
    char a[8], e[10], an[4], f[8], w[10], p[8], x[8];
    char pre[24], cur[8];
    double t0, st, d, dx, dy, sc, sx, sy, r, al, bob, bp, it, sz, ls, h, xd;
    unsigned int colors[8]; int ncolors;
    unsigned int glow; double glowr; int hasglow;
    unsigned int shadow; double shb, shx, shy; int hasshadow;
} Style;

static unsigned int hexcolor(const char *s) {
    char buf[9] = {0}; int n = 0;
    while (n < 8 && ((s[n] >= '0' && s[n] <= '9') || (s[n] >= 'a' && s[n] <= 'f') || (s[n] >= 'A' && s[n] <= 'F'))) { buf[n] = s[n]; n++; }
    unsigned int v = (unsigned int)strtoul(buf, NULL, 16);
    if (n <= 6) v = (v << 8) | 0xFF;   // no alpha given: opaque
    return v;
}

static void copyval(char *dst, size_t size, const char *src, size_t len) {
    if (len >= size) len = size - 1;
    memcpy(dst, src, len); dst[len] = 0;
}

static void parse_style(Style *s, const char *spec) {
    memset(s, 0, sizeof *s);
    strcpy(s->a, "line"); strcpy(s->e, "lin"); strcpy(s->an, "c"); strcpy(s->f, "sys"); strcpy(s->w, "bold");
    strcpy(s->x, "fade");
    s->t0 = 0.3; s->st = 0.05; s->d = 0.5; s->sc = 1; s->sx = 1; s->sy = 1; s->bp = 2; s->sz = 1; s->h = 4.5; s->xd = 0.7;
    s->colors[0] = 0xFFFFFFFF; s->ncolors = 1;
    s->hasshadow = 1; s->shadow = 0x000000D9; s->shb = 0.18; s->shx = 0; s->shy = -0.035;
    if (!spec) return;
    const char *p = spec;
    while (*p) {
        const char *end = strchr(p, ';'); if (!end) end = p + strlen(p);
        const char *eq = memchr(p, '=', (size_t)(end - p));
        if (eq) {
            char key[8] = {0}; copyval(key, sizeof key, p, (size_t)(eq - p));
            const char *v = eq + 1; size_t vl = (size_t)(end - v);
            char val[64] = {0}; copyval(val, sizeof val, v, vl);
            double num = atof(val);
            if (!strcmp(key, "a")) copyval(s->a, sizeof s->a, v, vl);
            else if (!strcmp(key, "e")) copyval(s->e, sizeof s->e, v, vl);
            else if (!strcmp(key, "an")) copyval(s->an, sizeof s->an, v, vl);
            else if (!strcmp(key, "f")) copyval(s->f, sizeof s->f, v, vl);
            else if (!strcmp(key, "w")) copyval(s->w, sizeof s->w, v, vl);
            else if (!strcmp(key, "p")) copyval(s->p, sizeof s->p, v, vl);
            else if (!strcmp(key, "x")) copyval(s->x, sizeof s->x, v, vl);
            else if (!strcmp(key, "pre")) copyval(s->pre, sizeof s->pre, v, vl);
            else if (!strcmp(key, "cur")) copyval(s->cur, sizeof s->cur, v, vl);
            else if (!strcmp(key, "t0")) s->t0 = num;
            else if (!strcmp(key, "st")) s->st = num;
            else if (!strcmp(key, "d")) s->d = num;
            else if (!strcmp(key, "dx")) s->dx = num;
            else if (!strcmp(key, "dy")) s->dy = num;
            else if (!strcmp(key, "sc")) s->sc = num;
            else if (!strcmp(key, "sx")) s->sx = num;
            else if (!strcmp(key, "sy")) s->sy = num;
            else if (!strcmp(key, "r")) s->r = num;
            else if (!strcmp(key, "al")) s->al = num;
            else if (!strcmp(key, "bob")) s->bob = num;
            else if (!strcmp(key, "bp")) s->bp = num > 0.2 ? num : 0.2;
            else if (!strcmp(key, "it")) s->it = num;
            else if (!strcmp(key, "sz")) s->sz = num > 0.3 ? num : 0.3;
            else if (!strcmp(key, "ls")) s->ls = num;
            else if (!strcmp(key, "h")) s->h = num;
            else if (!strcmp(key, "xd")) s->xd = num > 0.05 ? num : 0.05;
            else if (!strcmp(key, "c")) {
                s->ncolors = 0;
                const char *q = val;
                while (*q && s->ncolors < 8) {
                    s->colors[s->ncolors++] = hexcolor(q);
                    const char *comma = strchr(q, ','); if (!comma) break; q = comma + 1;
                }
                if (!s->ncolors) { s->colors[0] = 0xFFFFFFFF; s->ncolors = 1; }
            } else if (!strcmp(key, "gl")) {
                s->hasglow = 1; s->glow = hexcolor(val);
                const char *c1 = strchr(val, ':'); s->glowr = c1 ? atof(c1 + 1) : 0.2;
                s->hasshadow = 0;
            } else if (!strcmp(key, "sh")) {
                s->hasshadow = 1; s->shadow = hexcolor(val); s->shb = 0; s->shx = 0; s->shy = 0;
                const char *c1 = strchr(val, ':');
                if (c1) { s->shb = atof(c1 + 1); const char *c2 = strchr(c1 + 1, ':');
                    if (c2) { s->shx = atof(c2 + 1); const char *c3 = strchr(c2 + 1, ':'); if (c3) s->shy = atof(c3 + 1); } }
            }
        }
        p = *end ? end + 1 : end;
    }
    if (s->d < 0) s->d = 0;
    if (s->st < 0) s->st = 0;
}

// Easing: how far along (0 to 1, past 1 while overshooting) at t (0 to 1).
static double ease(const char *e, double t) {
    if (t <= 0) return 0;
    if (t >= 1) return 1;
    if (!strcmp(e, "out")) { double u = 1 - t; return 1 - u * u * u; }
    if (!strcmp(e, "back")) { const double c1 = 1.70158, c3 = c1 + 1; double u = t - 1; return 1 + c3 * u * u * u + c1 * u * u; }
    if (!strcmp(e, "elastic")) { return pow(2, -10 * t) * sin((t * 10 - 0.75) * (2 * M_PI / 3)) + 1; }
    if (!strcmp(e, "bounce")) {
        const double n1 = 7.5625, d1 = 2.75;
        if (t < 1 / d1) return n1 * t * t;
        if (t < 2 / d1) { t -= 1.5 / d1; return n1 * t * t + 0.75; }
        if (t < 2.5 / d1) { t -= 2.25 / d1; return n1 * t * t + 0.9375; }
        t -= 2.625 / d1; return n1 * t * t + 0.984375;
    }
    if (!strcmp(e, "step")) return 1;
    return t;   // lin
}

// ---- The greeting's layers ---------------------------------------------------------------------------------------
#define MAXL 96
typedef struct {
    Style st;
    id line, panel, cursor;
    id letters[MAXL];
    double cx[MAXL], wd[MAXL];   // each letter's middle and width, in the line
    int order[MAXL];
    int n;
    double fs, lineW, lineH;
    Pt home;                     // where the line's anchor sits on the screen
    int done;
} Greeting;

static id color(unsigned int rgba) {
    return MSG(id, double, double, double, double)(CLS("NSColor"), S("colorWithSRGBRed:green:blue:alpha:"),
        ((rgba >> 24) & 0xFF) / 255.0, ((rgba >> 16) & 0xFF) / 255.0, ((rgba >> 8) & 0xFF) / 255.0, (rgba & 0xFF) / 255.0);
}
static void *cgcolor(unsigned int rgba) { return MSG(void *)(color(rgba), S("CGColor")); }

static id font_for(const Style *s, double size) {
    id NSFont = CLS("NSFont");
    double weight = !strcmp(s->w, "semibold") ? 0.3 : !strcmp(s->w, "heavy") ? 0.56 : !strcmp(s->w, "regular") ? 0.0 : 0.4;
    id f = NULL;
    if (!strcmp(s->f, "mono"))
        f = MSG(id, double, double)(NSFont, S("monospacedSystemFontOfSize:weight:"), size, weight);
    if (!f) f = MSG(id, double, double)(NSFont, S("systemFontOfSize:weight:"), size, weight);
    if (!f) f = MSG(id, double)(NSFont, S("boldSystemFontOfSize:"), size);
    const char *design = !strcmp(s->f, "round") ? "NSFontDescriptorSystemDesignRounded"
                       : !strcmp(s->f, "serif") ? "NSFontDescriptorSystemDesignSerif" : NULL;
    if (design && appkit) {
        id *name = (id *)dlsym(appkit, design);
        if (name && *name) {
            id desc = MSG(id)(f, S("fontDescriptor"));
            id d2 = desc ? MSG(id, id)(desc, S("fontDescriptorWithDesign:"), *name) : NULL;
            id f2 = d2 ? MSG(id, id, double)(NSFont, S("fontWithDescriptor:size:"), d2, size) : NULL;
            if (f2) f = f2;
        }
    }
    if (s->it >= 1) {
        id desc = MSG(id)(f, S("fontDescriptor"));
        uint32_t traits = desc ? MSG(uint32_t)(desc, S("symbolicTraits")) : 0;
        id d2 = desc ? MSG(id, uint32_t)(desc, S("fontDescriptorWithSymbolicTraits:"), traits | 1u) : NULL;
        id f2 = d2 ? MSG(id, id, double)(NSFont, S("fontWithDescriptor:size:"), d2, size) : NULL;
        if (f2) f = f2;
    }
    return f;
}

static Sz measure(id str, id font) {
    id attrs = MSG(id, id, id)(CLS("NSDictionary"), S("dictionaryWithObject:forKey:"), font, nsstr("NSFont"));
    return MSG(Sz, id)(str, S("sizeWithAttributes:"), attrs);
}

static void tx_begin(void) {
    id T = CLS("CATransaction");
    MSG(void)(T, S("begin"));
    MSG(void, BOOL)(T, S("setDisableActions:"), 1);
}
static void tx_end(void) { MSG(void)(CLS("CATransaction"), S("commit")); }

static void set_frame_layer(id layer, Rect r, Pt anchor) {
    MSG(void, Pt)(layer, S("setAnchorPoint:"), anchor);
    MSG(void, Rect)(layer, S("setBounds:"), (Rect){{0, 0}, r.s});
    MSG(void, Pt)(layer, S("setPosition:"), (Pt){r.o.x + anchor.x * r.s.w, r.o.y + anchor.y * r.s.h});
}

static id text_layer(const Greeting *g, id str, id font, unsigned int rgba, double scale) {
    id L = MSG(id)(CLS("CATextLayer"), S("layer"));
    if (!L) return NULL;
    MSG(void, id)(L, S("setString:"), str);
    MSG(void, id)(L, S("setFont:"), font);
    MSG(void, double)(L, S("setFontSize:"), g->fs);
    MSG(void, void *)(L, S("setForegroundColor:"), cgcolor(rgba));
    MSG(void, id)(L, S("setAlignmentMode:"), nsstr("center"));
    MSG(void, double)(L, S("setContentsScale:"), scale);
    const Style *s = &g->st;
    if (s->hasglow) {
        MSG(void, void *)(L, S("setShadowColor:"), cgcolor(s->glow | 0xFF));
        MSG(void, float)(L, S("setShadowOpacity:"), (float)((s->glow & 0xFF) / 255.0));
        MSG(void, double)(L, S("setShadowRadius:"), s->glowr * g->fs);
        MSG(void, Sz)(L, S("setShadowOffset:"), (Sz){0, 0});
    } else if (s->hasshadow) {
        MSG(void, void *)(L, S("setShadowColor:"), cgcolor(s->shadow | 0xFF));
        MSG(void, float)(L, S("setShadowOpacity:"), (float)((s->shadow & 0xFF) / 255.0));
        MSG(void, double)(L, S("setShadowRadius:"), s->shb * g->fs);
        MSG(void, Sz)(L, S("setShadowOffset:"), (Sz){s->shx * g->fs, s->shy * g->fs});
    }
    return L;
}

// Sets up the greeting over the video (view: the main screen's content view, W x H). Returns 0 if it couldn't.
static int greeting_setup(Greeting *g, id view, const char *text, const char *spec, double W, double H, double scale) {
    memset(g, 0, sizeof *g);
    parse_style(&g->st, spec);
    Style *s = &g->st;
    if (!CLS("CATextLayer") || !CLS("CALayer")) return 0;
    char full[512];
    snprintf(full, sizeof full, "%s%s", s->pre, text);
    id str = nsstr(full);
    unsigned long len = MSG(unsigned long)(str, S("length"));
    if (!str || !len) return 0;

    // The letters (whole characters, so accents and emoji stay together)
    Range ranges[MAXL]; int n = 0;
    for (unsigned long i = 0; i < len && n < MAXL; ) {
        Range r = MSG(Range, unsigned long)(str, S("rangeOfComposedCharacterSequenceAtIndex:"), i);
        if (r.len == 0) r.len = 1;
        ranges[n++] = r;
        i = r.loc + r.len;
    }

    // Size: as before (a 19th of the screen's height, at least 28), smaller if the line wouldn't fit
    double fs = (H / 19 > 28 ? H / 19 : 28) * s->sz;
    id font = font_for(s, fs);
    Sz full_size = measure(str, font);
    double total = full_size.w + s->ls * fs * (n - 1);
    if (total > W - 80 && total > 0) {
        fs *= (W - 80) / total;
        font = font_for(s, fs);
        full_size = measure(str, font);
    }
    g->fs = fs; g->n = n; g->lineH = full_size.h > 0 ? full_size.h : fs * 1.25;
    for (int i = 0; i < n; i++) {
        id before = MSG(id, Range)(str, S("substringWithRange:"), (Range){0, ranges[i].loc});
        id upto = MSG(id, Range)(str, S("substringWithRange:"), (Range){0, ranges[i].loc + ranges[i].len});
        double x0 = ranges[i].loc ? measure(before, font).w : 0, x1 = measure(upto, font).w;
        double extra = s->ls * fs * i;
        g->cx[i] = (x0 + x1) / 2 + extra; g->wd[i] = x1 - x0;
    }
    g->lineW = full_size.w + s->ls * fs * (n - 1);
    double padX = 0.55 * fs, padY = 0.22 * fs;

    // The order the letters come in
    for (int i = 0; i < n; i++) g->order[i] = i;
    if (!strcmp(s->a, "rand")) {
        unsigned int seed = (unsigned int)(now() * 1000);
        for (int i = n - 1; i > 0; i--) { seed = seed * 1103515245u + 12345u; int j = (int)((seed >> 8) % (unsigned)(i + 1)); int t = g->order[i]; g->order[i] = g->order[j]; g->order[j] = t; }
    }

    int bottom = !strcmp(s->an, "b");
    tx_begin();
    id line = MSG(id)(CLS("CALayer"), S("layer"));
    g->line = line;
    double boxW = g->lineW + (s->p[0] ? 2 * padX : 0), boxH = g->lineH + (s->p[0] ? 2 * padY : 0);
    // Where the greeting goes: low on the picture, clear of the logo (as before 5.5.5).
    double y0 = H / 13 + 0.25 * fs - (s->p[0] ? padY : 0);
    Pt anchor = {0.5, bottom ? 0 : 0.5};
    set_frame_layer(line, (Rect){{(W - boxW) / 2, y0}, {boxW, boxH}}, anchor);
    g->home = (Pt){W / 2, y0 + anchor.y * boxH};
    MSG(void, float)(line, S("setOpacity:"), 0.0f);
    if (!strcmp(s->p, "glass") || !strcmp(s->p, "term")) {
        id panel = MSG(id)(CLS("CALayer"), S("layer"));
        int glass = !strcmp(s->p, "glass");
        set_frame_layer(panel, (Rect){{0, 0}, {boxW, boxH}}, (Pt){0.5, 0.5});
        MSG(void, void *)(panel, S("setBackgroundColor:"), cgcolor(glass ? 0xFFFFFF38 : 0x0B0F14C8));
        MSG(void, void *)(panel, S("setBorderColor:"), cgcolor(glass ? 0xFFFFFF8C : 0x4AF62659));
        MSG(void, double)(panel, S("setBorderWidth:"), glass ? 1.5 : 1.0);
        MSG(void, double)(panel, S("setCornerRadius:"), glass ? boxH / 2 : 0.18 * fs);
        if (glass) {
            MSG(void, void *)(panel, S("setShadowColor:"), cgcolor(0x000000FF));
            MSG(void, float)(panel, S("setShadowOpacity:"), 0.25f);
            MSG(void, double)(panel, S("setShadowRadius:"), 0.3 * fs);
            MSG(void, Sz)(panel, S("setShadowOffset:"), (Sz){0, -0.06 * fs});
        }
        MSG(void, id)(line, S("addSublayer:"), panel);
        g->panel = panel;
    }
    double ox = s->p[0] ? padX : 0, oy = s->p[0] ? padY : 0;
    for (int i = 0; i < n; i++) {
        id ls = MSG(id, Range)(str, S("substringWithRange:"), ranges[i]);
        id L = text_layer(g, ls, font, s->colors[i % s->ncolors], scale);
        if (!L) { tx_end(); return 0; }
        double w = g->wd[i] + 0.3 * fs;   // (a little room, so nothing is clipped while it turns)
        set_frame_layer(L, (Rect){{ox + g->cx[i] - w / 2, oy}, {w, g->lineH}}, anchor);
        MSG(void, float)(L, S("setOpacity:"), 0.0f);
        MSG(void, id)(line, S("addSublayer:"), L);
        g->letters[i] = L;
    }
    if (s->cur[0]) {
        id L = text_layer(g, nsstr(s->cur), font, s->colors[0], scale);
        if (L) {
            double w = measure(nsstr(s->cur), font).w + 0.3 * fs;
            set_frame_layer(L, (Rect){{ox + g->lineW, oy}, {w, g->lineH}}, (Pt){0.5, 0.5});
            MSG(void, float)(L, S("setOpacity:"), 0.0f);
            MSG(void, id)(line, S("addSublayer:"), L);
            g->cursor = L;
        }
    }
    MSG(void, id)(MSG(id)(view, S("layer")), S("addSublayer:"), line);
    tx_end();
    return 1;
}

static Affine pose(double sx, double sy, double rot_deg, double tx, double ty) {
    double rad = rot_deg * M_PI / 180, c = cos(rad), s = sin(rad);
    return (Affine){sx * c, sx * s, -sy * s, sy * c, tx, ty};
}

static double clamp01(double v) { return v < 0 ? 0 : v > 1 ? 1 : v; }

// Moves everything to where it is t seconds after the video started.
static void greeting_frame(Greeting *g, double t) {
    if (g->done || !g->line) return;
    const Style *s = &g->st;
    double fs = g->fs;
    int line_mode = !strcmp(s->a, "line"), step = !strcmp(s->e, "step");
    // How it goes away
    double q = clamp01((t - s->h) / s->xd), out = 1, drop = 0;
    if (!strcmp(s->x, "step")) out = q <= 0 ? 1 : (q < 0.2 ? 0 : q < 0.4 ? 1 : q < 0.6 ? 0 : q < 0.8 ? 1 : 0);
    else if (!strcmp(s->x, "drop")) { out = 1 - q; drop = q * q * 1.5 * fs; }
    else out = 1 - q;
    if (t > s->h + s->xd + 0.05) {
        tx_begin(); MSG(void, float)(g->line, S("setOpacity:"), 0.0f); tx_end();
        MSG(void)(g->line, S("removeFromSuperlayer"));
        g->done = 1;
        return;
    }
    // Long names: the letters come in faster, so they're all in within about two seconds
    double stagger = s->st;
    if (!line_mode && g->n > 1 && s->t0 + (g->n - 1) * stagger + s->d > 2.2)
        stagger = (2.2 - s->t0 - s->d) / (g->n - 1) > 0.012 ? (2.2 - s->t0 - s->d) / (g->n - 1) : 0.012;

    tx_begin();
    // The line as a whole
    double lineAlpha = 1, lsx = 1, lsy = 1, lrot = 0, ltx = 0, lty = 0;
    double p0 = s->d > 0 ? clamp01((t - s->t0) / s->d) : (t >= s->t0 ? 1 : 0);
    if (line_mode) {
        double k = step ? (p0 >= 1 ? 1 : 0) : ease(s->e, p0);
        double fade = step ? k : clamp01(p0 / 0.4);
        if (!strcmp(s->e, "lin")) fade = p0;
        lineAlpha = s->al + (1 - s->al) * fade;
        double sc = s->sc + (1 - s->sc) * k;
        lsx = sc * (s->sx + (1 - s->sx) * k); lsy = sc * (s->sy + (1 - s->sy) * k);
        lrot = s->r * (1 - k); ltx = s->dx * fs * (1 - k); lty = s->dy * fs * (1 - k);
        if (s->bob > 0) lty += s->bob * fs * sin(2 * M_PI * t / s->bp) * clamp01((t - s->t0) / 0.6);
    } else {
        lineAlpha = 1;
    }
    lty -= drop;
    MSG(void, float)(g->line, S("setOpacity:"), (float)(lineAlpha * out));
    MSG(void, Pt)(g->line, S("setPosition:"), (Pt){g->home.x, g->home.y});
    MSG(void, Affine)(g->line, S("setAffineTransform:"), pose(lsx < 0.001 ? 0.001 : lsx, lsy < 0.001 ? 0.001 : lsy, lrot, ltx, lty));
    if (g->panel) {
        double pa = line_mode ? 1 : clamp01((t - s->t0 + 0.1) / 0.35);
        MSG(void, float)(g->panel, S("setOpacity:"), (float)pa);
    }
    // Each letter
    int shown = 0;
    for (int j = 0; j < g->n; j++) {
        int i = g->order[j];
        id L = g->letters[i];
        if (line_mode) {
            MSG(void, float)(L, S("setOpacity:"), 1.0f);
            continue;
        }
        double start = s->t0 + j * stagger;
        double p = s->d > 0 ? clamp01((t - start) / s->d) : (t >= start ? 1 : 0);
        double k = step ? (t >= start ? 1 : 0) : ease(s->e, p);
        double alpha = step ? k : clamp01(p / 0.4);
        if (!strcmp(s->e, "lin")) alpha = p;
        alpha = s->al + (1 - s->al) * alpha;
        if (t < start) alpha = s->al > 0 ? s->al : 0;
        double sc = s->sc + (1 - s->sc) * k;
        double sx = sc * (s->sx + (1 - s->sx) * k), sy = sc * (s->sy + (1 - s->sy) * k);
        double tx = s->dx * fs * (1 - k), ty = s->dy * fs * (1 - k);
        if (s->bob > 0) ty += s->bob * fs * sin(2 * M_PI * t / s->bp - i * 0.6) * clamp01((t - start) / 0.6);
        MSG(void, float)(L, S("setOpacity:"), (float)alpha);
        MSG(void, Affine)(L, S("setAffineTransform:"), pose(sx < 0.001 ? 0.001 : sx, sy < 0.001 ? 0.001 : sy, s->r * (1 - k), tx, ty));
        if (t >= start) shown++;
    }
    if (g->cursor) {
        // After the last letter that's in (typing), blinking once they're all in
        double x = 0; int last = -1;
        for (int i = 0; i < g->n; i++) if (line_mode || t >= s->t0 + i * stagger) last = i;
        double ox = s->p[0] ? 0.55 * fs : 0;
        x = last >= 0 ? g->cx[last] + g->wd[last] / 2 : 0;
        Pt pos = MSG(Pt)(g->cursor, S("position"));
        double cw = MSG_RECT(g->cursor, S("bounds")).s.w;
        pos.x = ox + x + cw / 2 - 0.15 * g->fs;
        MSG(void, Pt)(g->cursor, S("setPosition:"), pos);
        int typing = !line_mode && shown < g->n;
        double blink = typing ? 1 : (fmod(t, 0.9) < 0.5 ? 1 : 0);
        MSG(void, float)(g->cursor, S("setOpacity:"), (float)(t >= s->t0 - 0.2 ? blink : 0));
    }
    tx_end();
}

int main(int argc, char **argv) {
    double t0 = now();
    const char *timing = getenv("TLA_PLAYER_TIMING");
    if (argc < 2 || access(argv[1], R_OK) != 0) { puts("error: no video file"); return 0; }
    int allowSkip = argc > 2 && !strcmp(argv[2], "1");
    double timeout = argc > 3 ? atof(argv[3]) : 60;
    if (timeout < 5) timeout = 5;
    const char *greeting = argc > 4 ? argv[4] : "";
    const char *style = argc > 5 ? argv[5] : "";

    void *objc = dlopen("/usr/lib/libobjc.A.dylib", RTLD_NOW);
    appkit = objc ? dlopen("/System/Library/Frameworks/AppKit.framework/AppKit", RTLD_NOW) : NULL;
    if (!objc || !appkit) { puts("error: AppKit"); return 0; }
    p_getClass = (Class (*)(const char *))dlsym(objc, "objc_getClass");
    p_sel = (SEL (*)(const char *))dlsym(objc, "sel_registerName");
    p_allocPair = (Class (*)(Class, const char *, size_t))dlsym(objc, "objc_allocateClassPair");
    p_registerPair = (void (*)(Class))dlsym(objc, "objc_registerClassPair");
    p_addMethod = (BOOL (*)(Class, SEL, void *, const char *))dlsym(objc, "class_addMethod");
    p_msg = dlsym(objc, "objc_msgSend");
    p_msg_stret = dlsym(objc, "objc_msgSend_stret");
    if (!p_getClass || !p_sel || !p_allocPair || !p_registerPair || !p_addMethod || !p_msg) { puts("error: AppKit"); return 0; }
#if defined(__x86_64__)
    if (!p_msg_stret) { puts("error: AppKit"); return 0; }
#endif

    // A borderless window that can still take the keyboard (for Esc), and the Skip button's target
    Class winClass = p_allocPair(CLS("NSWindow"), "TLAPlayerWindow", 0);
    p_addMethod(winClass, S("canBecomeKeyWindow"), (void *)yes, "B@:");
    p_addMethod(winClass, S("canBecomeMainWindow"), (void *)yes, "B@:");
    p_registerPair(winClass);
    Class skipClass = p_allocPair(CLS("NSObject"), "TLAPlayerSkip", 0);
    p_addMethod(skipClass, S("skip:"), (void *)skip, "v@:@");
    p_registerPair(skipClass);

    id app = MSG(id)(CLS("NSApplication"), S("sharedApplication"));
    MSG(void, long)(app, S("setActivationPolicy:"), 1);   // accessory: no Dock icon
    MSG(void)(app, S("finishLaunching"));

    // Black on every screen straight away; the video goes on the main one
    id screens = MSG(id)(CLS("NSScreen"), S("screens"));
    id mainScreen = MSG(id)(CLS("NSScreen"), S("mainScreen"));
    long count = (long)MSG(unsigned long)(screens, S("count"));
    if (count < 1) { puts("error: no screen"); return 0; }
    if (count > 16) count = 16;
    id windows[16]; id videoWin = NULL; id videoScreen = NULL;
    for (long i = 0; i < count; i++) {
        id screen = MSG(id, unsigned long)(screens, S("objectAtIndex:"), (unsigned long)i);
        Rect frame = MSG_RECT(screen, S("frame"));
        id w = MSG(id)((id)winClass, S("alloc"));
        w = MSG(id, Rect, unsigned long, unsigned long, BOOL)(w, S("initWithContentRect:styleMask:backing:defer:"), frame, 0, 2, 0);
        MSG(void, Rect, BOOL)(w, S("setFrame:display:"), frame, 1);
        MSG(void, id)(w, S("setBackgroundColor:"), MSG(id)(CLS("NSColor"), S("blackColor")));
        MSG(void, BOOL)(w, S("setOpaque:"), 1);
        MSG(void, long)(w, S("setLevel:"), 1000);                  // above the menu bar and Dock
        MSG(void, unsigned long)(w, S("setCollectionBehavior:"), 17);   // every Space, stays put
        MSG(void, BOOL)(w, S("setReleasedWhenClosed:"), 0);
        MSG(void)(w, S("orderFrontRegardless"));
        MSG(void)(w, S("display"));
        windows[i] = w;
        if (!videoWin || MSG(BOOL, id)(screen, S("isEqual:"), mainScreen)) { videoWin = w; videoScreen = screen; }
    }
    if (!videoWin) { puts("error: no screen"); return 0; }
    MSG(void, BOOL)(app, S("activateIgnoringOtherApps:"), 1);
    MSG(void, BOOL)(CLS("NSCursor"), S("setHiddenUntilMouseMoves:"), 1);
    id ev = MSG(id, unsigned long long, id, id, BOOL)(app, S("nextEventMatchingMask:untilDate:inMode:dequeue:"), ~0ULL,
        MSG(id, double)(CLS("NSDate"), S("dateWithTimeIntervalSinceNow:"), 0.01), nsstr("kCFRunLoopDefaultMode"), 1);
    if (ev) MSG(void, id)(app, S("sendEvent:"), ev);
    if (timing) fprintf(stderr, "covered after %.0f ms\n", (now() - t0) * 1000);

    if (!dlopen("/System/Library/Frameworks/AVFoundation.framework/AVFoundation", RTLD_NOW)) { puts("error: AVFoundation"); return 0; }
    id view = MSG(id)(videoWin, S("contentView"));
    MSG(void, BOOL)(view, S("setWantsLayer:"), 1);
    id url = MSG(id, id)(CLS("NSURL"), S("fileURLWithPath:"), nsstr(argv[1]));
    id player = MSG(id, id)(CLS("AVPlayer"), S("playerWithURL:"), url);
    id playerLayer = MSG(id, id)(CLS("AVPlayerLayer"), S("playerLayerWithPlayer:"), player);
    MSG(void, id)(playerLayer, S("setVideoGravity:"), nsstr("AVLayerVideoGravityResizeAspect"));
    Rect bounds = MSG_RECT(view, S("bounds"));
    MSG(void, Rect)(playerLayer, S("setFrame:"), bounds);
    MSG(void, unsigned int)(playerLayer, S("setAutoresizingMask:"), 18);
    MSG(void, id)(MSG(id)(view, S("layer")), S("addSublayer:"), playerLayer);

    if (allowSkip) {
        id button = MSG(id)(CLS("NSButton"), S("alloc"));
        button = MSG(id, Rect)(button, S("initWithFrame:"), (Rect){{0, 0}, {110, 36}});
        MSG(void, id)(button, S("setTitle:"), nsstr("Skip"));
        MSG(void, unsigned long)(button, S("setBezelStyle:"), 1);
        MSG(void, unsigned long)(button, S("setControlSize:"), 3);
        MSG(void, id)(button, S("setKeyEquivalent:"), nsstr("\x1b"));
        MSG(void)(button, S("sizeToFit"));
        Rect bf = MSG_RECT(button, S("frame"));
        MSG(void, Pt)(button, S("setFrameOrigin:"), (Pt){bounds.s.w - bf.s.w - 40, 40});
        MSG(void, unsigned long)(button, S("setAutoresizingMask:"), 33);
        id target = MSG(id)(MSG(id)((id)skipClass, S("alloc")), S("init"));
        MSG(void, id)(button, S("setTarget:"), target);
        MSG(void, SEL)(button, S("setAction:"), S("skip:"));
        MSG(void, id)(view, S("addSubview:"), button);
    }

    Greeting hello; int haveGreeting = 0;
    if (greeting[0]) {
        double scale = MSG(double)(videoScreen, S("backingScaleFactor"));
        if (scale < 1) scale = 2;
        haveGreeting = greeting_setup(&hello, view, greeting, style, bounds.s.w, bounds.s.h, scale);
    }

    MSG(void, id)(videoWin, S("makeKeyAndOrderFront:"), NULL);
    MSG(void, BOOL)(app, S("activateIgnoringOtherApps:"), 1);
    MSG(void)(player, S("play"));
    if (timing) fprintf(stderr, "playing after %.0f ms\n", (now() - t0) * 1000);

    double loopStart = now(), playStart = 0;
    int started = 0;
    while (state == 0) {
        double wait = haveGreeting && !hello.done && started ? 1.0 / 60 : 0.03;
        id e = MSG(id, unsigned long long, id, id, BOOL)(app, S("nextEventMatchingMask:untilDate:inMode:dequeue:"), ~0ULL,
            MSG(id, double)(CLS("NSDate"), S("dateWithTimeIntervalSinceNow:"), wait), nsstr("kCFRunLoopDefaultMode"), 1);
        if (e) MSG(void, id)(app, S("sendEvent:"), e);
        id item = MSG(id)(player, S("currentItem"));
        if (item && MSG(long)(item, S("status")) == 2) { state = 3; break; }   // failed
        float rate = MSG(float)(player, S("rate"));
        int waiting = 0;
        if (rate > 0) {
            if (!started) playStart = now();
            started = 1;
        } else if (started) {
            state = 1;   // it ended
        } else {
            waiting = 1;
        }
        if (started && haveGreeting) greeting_frame(&hello, now() - playStart);
        double elapsed = now() - loopStart;
        if (waiting && elapsed > 8) { state = 3; break; }   // never started
        if (elapsed > timeout) state = 1;
    }
    MSG(void)(player, S("pause"));
    for (long i = 0; i < count; i++) MSG(void, id)(windows[i], S("orderOut:"), NULL);
    puts(state == 1 ? "played" : state == 2 ? "skipped" : "error: the video did not play");
    return 0;
}
