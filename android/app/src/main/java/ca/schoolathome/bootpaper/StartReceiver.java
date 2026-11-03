package ca.schoolathome.bootpaper;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;

/** After a restart, and after each update of the app: the background, and the check every 15 minutes. */
public class StartReceiver extends BroadcastReceiver {
    @Override public void onReceive(Context c, Intent i) {
        Wall.schedule(c);
        PendingResult r = goAsync();
        new Thread(() -> { Wall.apply(c, false); r.finish(); }).start();
    }
}
