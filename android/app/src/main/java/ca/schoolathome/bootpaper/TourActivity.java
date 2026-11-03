package ca.schoolathome.bootpaper;

import android.app.Activity;
import android.graphics.Color;
import android.graphics.Typeface;
import android.os.Bundle;
import android.view.Gravity;
import android.widget.Button;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.TextView;

/** The Welcome to TLA tour. Opening the app also starts TLA BootPaper on this tablet (Android only lets an app run in
 *  the background once it has been opened). */
public class TourActivity extends Activity {
    private static final String[][] PAGES = {
        { "Welcome to TLA", "This tablet is set up by Traditional Learning Academy Online. Here's a quick look at how it works." },
        { "Your TLA background", "The lock screen shows the TLA background in dark mode, and the home screen shows it in light mode. In fall, at Christmas, in winter and at Easter it changes to that season's theme by itself." },
        { "Backgrounds are set by TLA", "If the background is changed, this tablet puts the TLA background back within about 15 minutes." },
        { "Need help?", "Email helpdesk@schoolathome.ca and tell us what's happening. Messages from TLA show on the lock screen." },
        { "You're all set", "Enjoy your TLA tablet!" },
    };
    private int page;
    private TextView title, body;
    private Button next;

    @Override protected void onCreate(Bundle b) {
        super.onCreate(b);
        Wall.schedule(this);
        new Thread(() -> Wall.apply(this, false)).start();
        float dp = getResources().getDisplayMetrics().density;
        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setGravity(Gravity.CENTER);
        root.setPadding((int) (32 * dp), (int) (32 * dp), (int) (32 * dp), (int) (32 * dp));
        root.setBackgroundColor(Color.parseColor("#F4F7FC"));
        ImageView logo = new ImageView(this);
        logo.setImageResource(R.mipmap.ic_launcher);
        root.addView(logo, new LinearLayout.LayoutParams((int) (96 * dp), (int) (96 * dp)));
        title = new TextView(this);
        title.setTextSize(28); title.setTypeface(Typeface.DEFAULT_BOLD); title.setTextColor(Color.parseColor("#13294B"));
        title.setGravity(Gravity.CENTER); title.setPadding(0, (int) (24 * dp), 0, (int) (12 * dp));
        root.addView(title);
        body = new TextView(this);
        body.setTextSize(18); body.setTextColor(Color.parseColor("#33415C")); body.setGravity(Gravity.CENTER);
        body.setMaxWidth((int) (560 * dp));
        root.addView(body);
        next = new Button(this);
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        lp.topMargin = (int) (32 * dp);
        root.addView(next, lp);
        next.setOnClickListener(v -> { if (++page >= PAGES.length) finish(); else show(); });
        setContentView(root);
        show();
    }

    private void show() {
        title.setText(PAGES[page][0]);
        body.setText(PAGES[page][1]);
        next.setText(page == PAGES.length - 1 ? "Done" : "Next");
    }
}
