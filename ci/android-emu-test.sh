O=out/emu; mkdir -p $O
adb install -r android/app/build/outputs/apk/debug/app-debug.apk > $O/log.txt 2>&1
adb shell am start -n ca.schoolathome.bootpaper/.TourActivity >> $O/log.txt 2>&1; sleep 15
adb exec-out screencap -p > $O/1-tour.png
adb shell input keyevent KEYCODE_HOME; sleep 5; adb exec-out screencap -p > $O/2-home.png
adb shell dumpsys jobscheduler | grep -A3 "ca.schoolathome.bootpaper" | head -8 >> $O/log.txt
adb shell dumpsys wallpaper | grep -iE "mWallpaperComponent|id=|which" | head -10 >> $O/log.txt
adb shell input keyevent KEYCODE_SLEEP; sleep 2; adb shell input keyevent KEYCODE_WAKEUP; sleep 3; adb exec-out screencap -p > $O/3-lock.png
adb shell cmd jobscheduler run -f ca.schoolathome.bootpaper 1 >> $O/log.txt 2>&1; sleep 5
echo done >> $O/log.txt
