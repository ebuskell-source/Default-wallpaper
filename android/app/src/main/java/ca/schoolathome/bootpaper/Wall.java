package ca.schoolathome.bootpaper;

import android.app.WallpaperManager;
import android.app.job.JobInfo;
import android.app.job.JobScheduler;
import android.content.ComponentName;
import android.content.Context;
import android.content.SharedPreferences;
import java.io.InputStream;
import java.util.Calendar;

/** TLA BootPaper for Android: the TLA background, dark on the lock screen and light on the home screen, put back if
 *  anyone changes it. The seasonal theme (same dates as on Windows, Macs and Linux) when it's in season. */
final class Wall {
    private Wall() { }

    /** fall, christmas, easter, winter, or null (then TLA's Android picture). Easter wins over winter. */
    static String season(Calendar d) {
        int m = d.get(Calendar.MONTH) + 1, day = d.get(Calendar.DAY_OF_MONTH);
        if ((m == 9 && day >= 22) || m == 10 || m == 11) return "fall";
        if (m == 12 || (m == 1 && day <= 6)) return "christmas";
        Calendar e = easter(d.get(Calendar.YEAR));
        Calendar from = (Calendar) e.clone(); from.add(Calendar.DAY_OF_MONTH, -14);
        Calendar to = (Calendar) e.clone(); to.add(Calendar.DAY_OF_MONTH, 2);
        if (!d.before(from) && d.before(to)) return "easter";
        if ((m == 1 && day >= 7) || m == 2 || (m == 3 && day <= 19)) return "winter";
        return null;
    }

    /** Easter Sunday (Gregorian), at midnight. */
    static Calendar easter(int y) {
        int a = y % 19, b = y / 100, c = y % 100, d = b / 4, e = b % 4, f = (b + 8) / 25, g = (b - f + 1) / 3;
        int h = (19 * a + b - d - g + 15) % 30, i = c / 4, k = c % 4, l = (32 + 2 * e + 2 * i - h - k) % 7;
        int m = (a + 11 * h + 22 * l) / 451, month = (h + l - 7 * m + 114) / 31, day = ((h + l - 7 * m + 114) % 31) + 1;
        Calendar r = Calendar.getInstance(); r.clear(); r.set(y, month - 1, day); return r;
    }

    private static int picture(Context c, String name) {
        return c.getResources().getIdentifier(name, "drawable", c.getPackageName());
    }

    /** Puts the TLA background in place if it isn't (someone changed it, or the season changed), or always if forced. */
    static synchronized void apply(Context c, boolean force) {
        WallpaperManager wm = WallpaperManager.getInstance(c);
        SharedPreferences p = c.getSharedPreferences("wall", Context.MODE_PRIVATE);
        String s = season(Calendar.getInstance()), base = "bg_" + (s == null ? "android" : s);
        boolean same = base.equals(p.getString("base", ""))
                && wm.getWallpaperId(WallpaperManager.FLAG_SYSTEM) == p.getInt("home", -2)
                && wm.getWallpaperId(WallpaperManager.FLAG_LOCK) == p.getInt("lock", -2);
        if (same && !force) return;
        try {
            try (InputStream in = c.getResources().openRawResource(picture(c, base))) {
                wm.setStream(in, null, true, WallpaperManager.FLAG_SYSTEM);          // home screen: light
            }
            try (InputStream in = c.getResources().openRawResource(picture(c, base + "_dark"))) {
                wm.setStream(in, null, true, WallpaperManager.FLAG_LOCK);            // lock screen: dark
            }
            p.edit().putString("base", base)
                    .putInt("home", wm.getWallpaperId(WallpaperManager.FLAG_SYSTEM))
                    .putInt("lock", wm.getWallpaperId(WallpaperManager.FLAG_LOCK)).apply();
        } catch (Exception e) {
            android.util.Log.w("TLABootPaper", "Couldn't set the wallpaper", e);
        }
    }

    /** Checks every 15 minutes (Android's shortest), also after a restart. */
    static void schedule(Context c) {
        JobScheduler js = c.getSystemService(JobScheduler.class);
        if (js.getPendingJob(1) != null) return;
        js.schedule(new JobInfo.Builder(1, new ComponentName(c, WallpaperJob.class))
                .setPeriodic(15 * 60 * 1000L).setPersisted(true).build());
    }
}
