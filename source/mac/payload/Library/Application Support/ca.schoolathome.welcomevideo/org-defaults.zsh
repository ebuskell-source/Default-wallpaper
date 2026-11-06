# org-defaults.zsh
# Organization defaults for TLA BootPaper on Macs. People can change these for themselves in the
# TLA BootPaper app, unless ORG_UsersCanChange=0. Edit before building the package.

ORG_Enabled=1              # 1 = play the video at login, 0 = don't
ORG_PlayWhen=EverySignIn   # EverySignIn = every login
                           # OncePerDay  = first login each day
                           # AfterUpdate = first login after macOS installs an update
                           # FirstTime   = once per person, and again when the video changes
ORG_Sound=1                # 1 = with sound, 0 = muted
ORG_AllowSkip=0            # 1 = there's a Skip button (and Esc works), 0 = it plays to the end
ORG_Background=liquid-glass  # tla | frutiger-aero | liquid-glass | microsoft | rainy | code | bricks | blocks | space | claymation | solarpunk | anime | ocean | beach | penguins | pixel | sky-city
                             # | grumpy-cat | bonjovi | raccoon (5.9.0)
                             # Everyone gets this (desktop and lock screen) at their next login unless they pick another preset.
ORG_Video=match            # match (the video that goes with their background) | tla | frutiger-aero
                           # | liquid-glass | microsoft | rainy | code | bricks | blocks | space | claymation | solarpunk | anime | beach
                           # | frutiger-aero-v2 (the newer Frutiger Aero video) | liquid-glass-original | microsoft-original
                           # (the first versions of those two)
ORG_Channel=stable         # stable | experimental: when new backgrounds, videos and features reach people (4.3)
ORG_UsersCanChange=1       # 0 = people can see these settings in the app but not change them
ORG_OwnPictures=           # (5.9.0) their own pictures in the app: empty = on Macs that belong to the person (not set up
                           # through Apple School or Business Manager), 1 = on every Mac, 0 = on none

# The video window (same look as before).
DIALOG_TITLE="Welcome to TLA"
AUTO_CLOSE_SECONDS=12      # the videos are 10 seconds long
