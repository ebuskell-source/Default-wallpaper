// launcher.c - TLA BootPaper (5.8.0): the TLA BootPaper app's own program, Contents/MacOS/welcome-video.
//   welcome-video [arguments]                   opening the app: runs settings.zsh with the same arguments
//   welcome-video --jxa <script.js> [arguments] runs a JavaScript for Automation window script in this program, like
//                                               "osascript -l JavaScript <script.js> [arguments]", and prints what
//                                               its run() returns
// 5.8.0: the app window (settings-app.js) runs here instead of in osascript, so macOS sees it as the TLA BootPaper app:
// its name and icon in the Dock while it's open, and in the menu bar. Exit codes with --jxa: 0 = the script ran (or
// the person chose Quit), 3 = it couldn't run here (settings.zsh then uses osascript instead).
// 6.0.5: opening the app runs its window right here, in the program macOS started, instead of in a second copy that
// settings.zsh started (5.8.0 to 5.9.5). With two, macOS sometimes didn't show the window when the app was opened
// again, and didn't pass "Quit" (from the Dock, or at log out) on to it: the app looked open with no window until it
// was force quit. Quitting now ends it straight away. If the window can't run here, settings.zsh takes over
// (TB_APP_FALLBACK=1: osascript, then the simple window), as before.
// Like player.c it talks to the Objective-C runtime directly, so it builds without Apple's headers (zig cc, see
// build-player.sh); each message is sent through objc_msgSend cast to the exact type of the method.
#include <dlfcn.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>

typedef void *id;
typedef void *SEL;

static id (*p_getClass)(const char *);
static SEL (*p_sel)(const char *);
static void *p_msg;
static id (*p_allocClass)(id, const char *, size_t);
static int (*p_addMethod)(id, SEL, void *, const char *);
static void (*p_registerClass)(id);
static char result_text[512];   // (what the window script's run() returned, for the app's own window)
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

// 6.0.5: "Quit" from the Dock or the menu bar, or logging out: AppKit says the app is about to end, and it ends right
// then. (Left to AppKit, ending in the middle of the window script left it running with no window.)
static void will_terminate(id self, SEL cmd, id note) {
    fflush(stdout);
    _exit(0);
}
static void watch_for_quit(void) {
    if (!p_allocClass || !p_addMethod || !p_registerClass) return;
    id cls = p_getClass("TBQuitWatcher");
    if (!cls) {
        cls = p_allocClass(CLS("NSObject"), "TBQuitWatcher", 0);
        if (!cls) return;
        p_addMethod(cls, S("willTerminate:"), (void *)will_terminate, "v@:@");
        p_registerClass(cls);
    }
    id watcher = MSG(id)(MSG(id)(cls, S("alloc")), S("init"));
    id center = MSG(id)(CLS("NSNotificationCenter"), S("defaultCenter"));
    MSG(void, id, SEL, id, id)(center, S("addObserver:selector:name:object:"), watcher, S("willTerminate:"),
                               nsstr("NSApplicationWillTerminateNotification"), NULL);
}

// host <script> <arguments for its run()>: 0 = it ran (its result printed, and kept in result_text), 3 = it couldn't.
static int host(const char *path, int argc, char **argv) {
    void *objc = dlopen("/usr/lib/libobjc.A.dylib", RTLD_NOW);
    if (!objc) return fail("libobjc", NULL);
    p_getClass = (id (*)(const char *))dlsym(objc, "objc_getClass");
    p_sel = (SEL (*)(const char *))dlsym(objc, "sel_registerName");
    p_msg = dlsym(objc, "objc_msgSend");
    p_allocClass = (id (*)(id, const char *, size_t))dlsym(objc, "objc_allocateClassPair");
    p_addMethod = (int (*)(id, SEL, void *, const char *))dlsym(objc, "class_addMethod");
    p_registerClass = (void (*)(id))dlsym(objc, "objc_registerClassPair");
    if (!p_getClass || !p_sel || !p_msg) return fail("objc", NULL);
    if (!dlopen("/System/Library/Frameworks/AppKit.framework/AppKit", RTLD_NOW)) return fail("AppKit", NULL);
    if (!dlopen("/System/Library/Frameworks/OSAKit.framework/OSAKit", RTLD_NOW)) return fail("OSAKit", NULL);
    if (!CLS("OSAScript") || !CLS("OSALanguage") || !CLS("NSAppleEventDescriptor")) return fail("OSAKit classes", NULL);

    MSG(id)(MSG(id)(CLS("NSAutoreleasePool"), S("alloc")), S("init"));
    MSG(id)(CLS("NSApplication"), S("sharedApplication"));   // (the script sets the rest up, as it does in osascript)
    watch_for_quit();

    id src = MSG(id, id, unsigned long, id *)(CLS("NSString"), S("stringWithContentsOfFile:encoding:error:"),
                                              nsstr(path), 4 /* UTF-8 */, NULL);
    if (!src) return fail("can't read the script", NULL);
    id lang = MSG(id, id)(CLS("OSALanguage"), S("languageForName:"), nsstr("JavaScript"));
    if (!lang) return fail("no JavaScript", NULL);
    id script = MSG(id, id, id)(MSG(id)(CLS("OSAScript"), S("alloc")), S("initWithSource:language:"), src, lang);
    id info = NULL;
    if (!script || !MSG(_Bool, id *)(script, S("compileAndReturnError:"), &info)) return fail("compile", info);

    // Its run(argv) handler, the way osascript calls it: an "open application" event (aevt/oapp) whose direct
    // object is the list of arguments.
    id list = MSG(id)(CLS("NSAppleEventDescriptor"), S("listDescriptor"));
    for (int i = 0; i < argc; i++) {
        id item = MSG(id, id)(CLS("NSAppleEventDescriptor"), S("descriptorWithString:"), nsstr(argv[i]));
        MSG(void, id, long)(list, S("insertDescriptor:atIndex:"), item, (long)(i + 1));
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
    snprintf(result_text, sizeof result_text, "%s", text ? text : "");
    return 0;
}

#define WV_DIR "/Library/Application Support/ca.schoolathome.welcomevideo"

int main(int argc, char **argv) {
    if (argc >= 3 && !strcmp(argv[1], "--jxa")) return host(argv[2], argc - 3, argv + 3);
    // 6.0.5: opening the app: its window, here (with "--report" or "--signin-now" when that's what it was opened with).
    if (!getenv("TB_APP_FALLBACK") && !getenv("TB_TEST")) {
        char *wargs[2];
        int wn = 0;
        wargs[wn++] = WV_DIR "/settings.zsh";
        if (argc > 1 && (!strcmp(argv[1], "--report") || !strcmp(argv[1], "--signin-now"))) wargs[wn++] = argv[1];
        int rc = host(WV_DIR "/settings-app.js", wn, wargs);
        if (rc == 0 && strncmp(result_text, "error", 5)) _exit(0);   // (closed, or quit: nothing left to do)
        setenv("TB_APP_FALLBACK", rc == 0 ? result_text : "it couldn't run here", 1);
    }
    // settings.zsh, with the same arguments (not the "-psn_..." one older macOS versions added).
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
