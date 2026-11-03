package ca.schoolathome.bootpaper;

import android.app.Activity;
import android.graphics.Color;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.os.Bundle;
import android.view.Gravity;
import android.view.View;
import android.view.WindowInsets;
import android.view.WindowInsetsController;
import android.widget.Button;
import android.widget.FrameLayout;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.TextView;
import java.util.Calendar;

/** Welcome to TLA: the same full-screen tour as on Windows and Macs, over the TLA background (the season's, dark).
 *  Opening it also starts TLA BootPaper on this tablet: Android only lets an app run in the background once opened. */
public class TourActivity extends Activity {
    private static final String[][] PAGES = {
        { "Welcome to TLA!", "This tablet comes from Traditional Learning Academy Online. Here's a quick look at what's on it." },
        { "Your TLA background", "The lock screen shows the TLA background in dark, and the home screen in light. In fall, at Christmas, in winter and at Easter, it changes to that season's look by itself." },
        { "Backgrounds come from TLA", "This tablet keeps the TLA background. If it's changed, the TLA background comes back within about 15 minutes." },
        { "News from TLA", "Messages from TLA, like reminders and announcements, show on the lock screen." },
        { "Help is one email away", "Something not working? Email helpdesk@schoolathome.ca and tell us what's happening. Say which tablet it is, and the helpdesk can help faster." },
        { "You're all set!", "Enjoy your TLA tablet. You can take this tour again any time: open TLA BootPaper." },
    };
    private int page;
    private TextView heading, body, dots;
    private Button next, back;

    private int dp(float v) { return (int) (v * getResources().getDisplayMetrics().density); }

    @Override protected void onCreate(Bundle b) {
        super.onCreate(b);
        Wall.schedule(this);
        new Thread(() -> Wall.apply(this, false)).start();

        FrameLayout root = new FrameLayout(this);
        root.setBackgroundColor(Color.parseColor("#0B1B33"));
        ImageView bg = new ImageView(this);
        String s = Wall.season(Calendar.getInstance());
        bg.setImageResource(getResources().getIdentifier("bg_" + (s == null ? "android" : s) + "_dark", "drawable", getPackageName()));
        bg.setScaleType(ImageView.ScaleType.CENTER_CROP);
        root.addView(bg, new FrameLayout.LayoutParams(-1, -1));
        View shade = new View(this);
        shade.setBackground(new GradientDrawable(GradientDrawable.Orientation.LEFT_RIGHT,
                new int[] { Color.argb(235, 8, 18, 36), Color.argb(150, 8, 18, 36), Color.argb(40, 8, 18, 36) }));
        root.addView(shade, new FrameLayout.LayoutParams(-1, -1));

        LinearLayout col = new LinearLayout(this);
        col.setOrientation(LinearLayout.VERTICAL);
        col.setGravity(Gravity.CENTER_VERTICAL);
        col.setPadding(dp(56), dp(48), dp(56), dp(48));
        ImageView logo = new ImageView(this);
        logo.setImageResource(R.mipmap.ic_launcher);
        col.addView(logo, new LinearLayout.LayoutParams(dp(72), dp(72)));
        heading = new TextView(this);
        heading.setTextColor(Color.WHITE); heading.setTextSize(38); heading.setTypeface(Typeface.create("sans-serif-medium", Typeface.NORMAL));
        heading.setPadding(0, dp(24), 0, dp(12)); heading.setMaxWidth(dp(620));
        col.addView(heading);
        body = new TextView(this);
        body.setTextColor(Color.argb(235, 255, 255, 255)); body.setTextSize(19); body.setLineSpacing(0, 1.2f); body.setMaxWidth(dp(620));
        col.addView(body);
        dots = new TextView(this);
        dots.setTextColor(Color.WHITE); dots.setTextSize(14); dots.setPadding(0, dp(28), 0, dp(16));
        col.addView(dots);
        LinearLayout row = new LinearLayout(this);
        back = new Button(this); back.setText("Back"); back.setAllCaps(false);
        next = new Button(this); next.setAllCaps(false);
        GradientDrawable pill = new GradientDrawable(); pill.setColor(Color.WHITE); pill.setCornerRadius(dp(24));
        next.setBackground(pill); next.setTextColor(Color.parseColor("#13294B")); next.setPadding(dp(28), 0, dp(28), 0);
        back.setBackgroundColor(Color.TRANSPARENT); back.setTextColor(Color.WHITE);
        row.addView(back, new LinearLayout.LayoutParams(-2, dp(48)));
        LinearLayout.LayoutParams np = new LinearLayout.LayoutParams(-2, dp(48)); np.leftMargin = dp(12);
        row.addView(next, np);
        col.addView(row);
        root.addView(col, new FrameLayout.LayoutParams(-1, -1));

        back.setOnClickListener(v -> { if (page > 0) { page--; show(); } });
        next.setOnClickListener(v -> {
            if (++page >= PAGES.length) {
                getSharedPreferences("wall", MODE_PRIVATE).edit().putBoolean("tourDone", true).apply();
                finish();
            } else show();
        });
        setContentView(root);
        WindowInsetsController c = getWindow().getInsetsController();
        if (c != null) { c.hide(WindowInsets.Type.systemBars()); c.setSystemBarsBehavior(WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE); }
        show();
    }

    private void show() {
        heading.setText(PAGES[page][0]);
        body.setText(PAGES[page][1]);
        StringBuilder d = new StringBuilder();
        for (int i = 0; i < PAGES.length; i++) d.append(i == page ? "● " : "○ ");
        dots.setText(d.toString().trim());
        back.setVisibility(page == 0 ? View.GONE : View.VISIBLE);
        next.setText(page == PAGES.length - 1 ? "Done" : "Next");
    }
}
