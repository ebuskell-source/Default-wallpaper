// launcher.c - TLA BootPaper (5.8.0): the TLA BootPaper app's own program, Contents/MacOS/welcome-video.
//   welcome-video [arguments]                   opening the app: runs settings.zsh with the same arguments
//   welcome-video --jxa <script.js> [arguments] runs a JavaScript for Automation window script in this program, like
//                                               "osascript -l JavaScript <script.js> [arguments]", and prints what
//                                               its run() returns
// 5.8.0: the app window (settings-app.js) runs here instead of in osascript, so macOS sees it as the TLA BootPaper app:
// its name and icon in the Dock while it's open, and in the menu bar. Exit codes with --jxa: 0 = the script ran (or
// the person chose Quit), 3 = it couldn't run here (settings.zsh then uses osascript instead).
// Like player.c it talks to the Objective-C runtime directly, so it builds without Apple's headers (zig cc, see
// build-player.sh); each message is sent through objc_msgSend cast to the exact type of the method.
#include <dlfcn.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

typedef void *id;
typedef void *SEL;

static id (*p_getClass)(const char *);
static SEL (*p_sel)(const char *);
static void *p_msg;
#define MSG(ret, ...) ((ret (*)(id, SEL, ##__VA_ARGS__))p_msg)
#define CLS(name) p_getClass(name)
#define S(name) p_sel(name)

static id nsstr(const char *s) { return MSG(id, const char *)(CLS("NSString"), S("stringWithUTF8String:"), s); }
static const char *cstr(id s) { return s ? MSG(const char *)(s, S("UTF8String")) : NULL; }

static int fail(const char *what, id info) {   // info: OSAKit's error dictionary, if any
    const char *d = info ? cstr(MSG(id)(info, S("description"))) : NULL;
    fprintf(stderr, "host-error: %s%s%s\n", what, d ? ": " : "", d ? d : "");
    return 3;
}

static int host(int argc, char **argv) {
    void *objc = dlopen("/usr/lib/libobjc.A.dylib", RTLD_NOW);
    if (!objc) return fail("libobjc", NULL);
    p_getClass = (id (*)(const char *))dlsym(objc, "objc_getClass");
    p_sel = (SEL (*)(const char *))dlsym(objc, "sel_registerName");
    p_msg = dlsym(objc, "objc_msgSend");
    if (!p_getClass || !p_sel || !p_msg) return fail("objc", NULL);
    if (!dlopen("/System/Library/Frameworks/AppKit.framework/AppKit", RTLD_NOW)) return fail("AppKit", NULL);
    if (!dlopen("/System/Library/Frameworks/OSAKit.framework/OSAKit", RTLD_NOW)) return fail("OSAKit", NULL);
    if (!CLS("OSAScript") || !CLS("OSALanguage") || !CLS("NSAppleEventDescriptor")) return fail("OSAKit classes", NULL);

    MSG(id)(MSG(id)(CLS("NSAutoreleasePool"), S("alloc")), S("init"));
    MSG(id)(CLS("NSApplication"), S("sharedApplication"));   // (the script sets the rest up, as it does in osascript)

    id src = MSG(id, id, unsigned long, id *)(CLS("NSString"), S("stringWithContentsOfFile:encoding:error:"),
                                              nsstr(argv[2]), 4 /* UTF-8 */, NULL);
    if (!src) return fail("can't read the script", NULL);
    id lang = MSG(id, id)(CLS("OSALanguage"), S("languageForName:"), nsstr("JavaScript"));
    if (!lang) return fail("no JavaScript", NULL);
    id script = MSG(id, id, id)(MSG(id)(CLS("OSAScript"), S("alloc")), S("initWithSource:language:"), src, lang);
    id info = NULL;
    if (!script || !MSG(_Bool, id *)(script, S("compileAndReturnError:"), &info)) return fail("compile", info);

    // Its run(argv) handler, the way osascript calls it: an "open application" event (aevt/oapp) whose direct
    // object is the list of arguments.
    id list = MSG(id)(CLS("NSAppleEventDescriptor"), S("listDescriptor"));
    for (int i = 3; i < argc; i++) {
        id item = MSG(id, id)(CLS("NSAppleEventDescriptor"), S("descriptorWithString:"), nsstr(argv[i]));
        MSG(void, id, long)(list, S("insertDescriptor:atIndex:"), item, (long)(i - 2));
    }
    id event = MSG(id, uint32_t, uint32_t, id, int16_t, int32_t)(CLS("NSAppleEventDescriptor"),
        S("appleEventWithEventClass:eventID:targetDescriptor:returnID:transactionID:"),
        0x61657674u /* aevt */, 0x6F617070u /* oapp */, MSG(id)(CLS("NSAppleEventDescriptor"), S("nullDescriptor")),
        (int16_t)-1 /* kAutoGenerateReturnID */, 0 /* kAnyTransactionID */);
    MSG(void, id, uint32_t)(event, S("setParamDescriptor:forKeyword:"), list, 0x2D2D2D2Du /* ---- */);
    info = NULL;
    id result = MSG(id, id, id *)(script, S("executeAppleEvent:error:"), event, &info);
    if (!result) return fail("run", info);
    const char *text = cstr(MSG(id)(result, S("stringValue")));
    printf("%s\n", text ? text : "");
    fflush(stdout);
    return 0;
}

int main(int argc, char **argv) {
    if (argc >= 3 && !strcmp(argv[1], "--jxa")) return host(argc, argv);
    // Opening the app: settings.zsh, with the same arguments (not the "-psn_..." one older macOS versions added).
    char *args[66];
    int n = 0;
    args[n++] = "/bin/zsh";
    args[n++] = "/Library/Application Support/ca.schoolathome.welcomevideo/settings.zsh";
    for (int i = 1; i < argc && n < 65; i++)
        if (strncmp(argv[i], "-psn_", 5)) args[n++] = argv[i];
    args[n] = NULL;
    execv("/bin/zsh", args);
    perror("TLA BootPaper: /bin/zsh");
    return 1;
}
