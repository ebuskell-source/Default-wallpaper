package ca.schoolathome.bootpaper;

import android.app.job.JobParameters;
import android.app.job.JobService;

public class WallpaperJob extends JobService {
    @Override public boolean onStartJob(JobParameters params) {
        new Thread(() -> { Wall.apply(this, false); jobFinished(params, false); }).start();
        return true;
    }
    @Override public boolean onStopJob(JobParameters params) { return true; }
}
