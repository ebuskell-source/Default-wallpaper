#!/usr/bin/python3
# TLA BootPaper for Linux (Ubuntu with GNOME). install.sh (run by the Intune Linux script) puts it in one of two places:
#   for everyone:     /opt/tla-bootpaper, when the script runs as root
#   for one person:   ~/.local/share/tla-bootpaper, when it runs as that person (Intune "User" context, 3.5.5),
#                     so nobody needs an administrator password. Same features; the background guard is a
#                     systemd user timer instead of a system one.
#
#   tla-bootpaper.py app                 the TLA BootPaper window (Activities > TLA BootPaper)
#   tla-bootpaper.py login               at every login (/etc/xdg/autostart): intro video, background, What's new
#   tla-bootpaper.py play                play the intro video now (always closable)
#   tla-bootpaper.py apply [--if-needed] put the person's preset background on their desktop and lock screen
#   tla-bootpaper.py guard               every 20 seconds (systemd timer): keeps the desktop to the preset (so the
#                                        background can only be changed in the app), downloads videos. As root it
#                                        looks after everyone; installed for one person, just that person
#   tla-bootpaper.py sync-videos         download any intro video that's missing or out of date
#   tla-bootpaper.py update              check GitHub for a new version now (the guard does this every 6 hours)
#   tla-bootpaper.py report              "Report a problem" on its own (4.3; Activities > Report a problem to TLA)
#   tla-bootpaper.py details             this computer's details, as the report includes them (4.3)
#   tla-bootpaper.py care                TLA Care on its own (5.0; Activities > TLA Care)
#   tla-bootpaper.py tour                the Welcome to TLA tour (5.0)
#   tla-bootpaper.py care-checks         TLA Care's checks, as text (5.0)
#   tla-bootpaper.py app --signin        the app, signing in straight away (5.7.0: a reminder's Sign in button)
#   tla-bootpaper.py signin-status       this person's sign-in, as JSON (5.7.0)
#
# Same choices and rules as the Windows and Mac versions:
#   Organization defaults: /etc/tla-bootpaper/org-defaults.json (people can change them for themselves unless
#                          UsersCanChange is 0)
#   Each person's choices: ~/.config/tla-bootpaper/settings.json (only what differs from the defaults)
#   What has happened:     ~/.config/tla-bootpaper/state.json

import base64
import datetime
import hashlib
import hmac
import json
import math
import os
import platform
import pwd
import re
import shutil
import subprocess
import sys
import tempfile
import threading
import time
import urllib.error
import urllib.request

APP_DIR = os.path.dirname(os.path.abspath(__file__))
RELEASE = '7.4.0' # this bundle's version (4.3: what people see also depends on their release channel)
ORG_FILE = '/etc/tla-bootpaper/org-defaults.json'
HELPDESK = 'helpdesk@schoolathome.ca'
STAFF_PAGE = 'https://ebuskell-source.github.io/Default-wallpaper/TLA-BootPaper/admin/'   # (5.6.0)
VIDEO_SOURCE = 'https://raw.githubusercontent.com/ebuskell-source/Default-wallpaper/main/TLA-BootPaper/videos'
VIDEO_DIR = os.path.join(APP_DIR, 'Videos')
# The Intune Linux script, also used to update itself (3.6): see self_update().
UPDATE_SCRIPT = 'https://raw.githubusercontent.com/ebuskell-source/Default-wallpaper/main/TLA-BootPaper/linux/tla-bootpaper-linux.sh'
# Announcements (4.0): a text file on GitHub that the organization edits. (Intune only reaches these computers
# while the admin account is signed in, so it can't deliver them.) Shown on the login screen and at login.
ANNOUNCEMENT_URL = 'https://raw.githubusercontent.com/ebuskell-source/Default-wallpaper/main/TLA-BootPaper/linux/announcement.txt'
ANNOUNCEMENT_FILE = '/etc/tla-bootpaper/announcement.txt'
LOG_FILE = '/var/log/tla-bootpaper.log'
# Release channels (4.3). Each release is marked Stable or Experimental. Everyone gets the same bundle, but new
# backgrounds, videos and features only show for people on a channel that has their release: Experimental first,
# Stable once it's been tried. People pick their channel in the app (organization default: Stable). SINCE: the
# release that brought something; anything not listed has been out for longer. The newest marks come from
# channels.json on GitHub (the guard reads it every 15 minutes), so a release can move to Stable without a new bundle.
CHANNELS = [('stable', 'Stable'), ('experimental', 'Experimental')]
CHANNEL_MARKS = {'stable': '7.4.0', 'experimental': '7.4.0'}   # as marked when this bundle was made (7.2.5: Stable, one version number on every platform)
SINCE = {'sky-city': '4.3', 'report': '4.3', 'lightdark': '5.0', 'calls': '5.0', 'care': '5.0', 'tour': '5.0',
         'beach': '5.4', 'anime-dark': '5.4', 'pixel-dark': '5.4.5', 'claymation-dark': '5.4.5',
         'greeting-styles': '5.5.5', 'greeting-switch': '5.5.5',
         'solarpunk-dark': '5.6.0', 'sky-city-dark': '5.6.0', 'space-light': '5.6.0', 'ocean-dark': '5.6.0',
         'signin': '5.7.0', 'checkupdates': '5.8.0',
         'grumpy-cat': '5.9.0', 'grumpy-cat-dark': '5.9.0', 'bonjovi': '5.9.0', 'bonjovi-dark': '5.9.0',
         'raccoon': '5.9.0', 'ownpictures': '5.9.0', 'code-light': '6.0.5', 'vancouver': '6.4.5'}   # (5.4: '<id>-<style>' = that background's second intro video)
CHANNELS_URL = 'https://raw.githubusercontent.com/ebuskell-source/Default-wallpaper/main/TLA-BootPaper/channels.json'
CHANNELS_FILE = os.path.join(APP_DIR, 'channels.json')

SETTINGS = ['Enabled', 'PlayWhen', 'Sound', 'AllowSkip', 'Background', 'Video', 'QuietMode', 'QuietStart',
            'QuietEnd', 'QuietDays', 'PreferredName', 'WallpaperFit', 'TempBackground', 'TempUntil', 'Channel',
            'LightDark', 'CareReminders', 'Greeting']   # (5.6.0: Greeting, on or off, keeping their name)
DEFAULTS = {'Enabled': 1, 'PlayWhen': 'EverySignIn', 'Sound': 1, 'AllowSkip': 0, 'Background': 'penguins',
            'Video': 'match', 'QuietMode': 'Off', 'QuietStart': '08:30', 'QuietEnd': '15:00',
            'QuietDays': 'Mon,Tue,Wed,Thu,Fri', 'PreferredName': '', 'UsersCanChange': 1,
            'WallpaperFit': 'Fill', 'TempBackground': '', 'TempUntil': '', 'Channel': 'stable',
            'LightDark': 'Auto', 'CareReminders': 1, 'Greeting': 1}
# 4.2: how the desktop picture fits the screen (and GNOME's name for it), and how long a pick lasts ("Use my
# pick"; not saved: each time the app opens, a pick is for good unless they choose otherwise). (GNOME's lock screen
# always shows the desktop picture, so there's no separate lock screen choice on Linux.)
FITS = [('Fill', 'Fill the screen', 'zoom'), ('Fit', 'Show the whole picture', 'scaled'),
        ('Span', 'Stretch across all my screens', 'spanned')]
PICK_FOR = [('Always', 'From now on'), ('Tomorrow', 'Just for today'), ('Week', 'For one week')]
# Light and dark (5.0): every background has a second picture for the other style (5.1.5: Underwater too). The value
# is the style of that extra picture (Backgrounds/<id>-<style>.jpg, thumbs/<id>-<style>.jpg); the original is the
# other one. GNOME switches between them by itself (picture-uri and picture-uri-dark), following Settings >
# Appearance > Style.
LIGHT_DARK = [('Auto', 'Match my light or dark style'), ('Light', 'Always light'), ('Dark', 'Always dark')]
VARIANTS = {'microsoft': 'dark', 'liquid-glass': 'dark', 'frutiger-aero': 'dark', 'solarpunk': 'dark', 'rainy': 'dark',
            'claymation': 'dark', 'blocks': 'dark', 'bricks': 'dark', 'pixel': 'dark', 'anime': 'dark',
            'sky-city': 'dark', 'tla': 'dark', 'penguins': 'light', 'code': 'light', 'space': 'light',
            'ocean': 'dark', 'beach': 'dark', 'fall': 'dark', 'christmas': 'dark', 'easter': 'dark',
            'grumpy-cat': 'dark', 'bonjovi': 'dark', 'raccoon': 'dark', 'vancouver': 'dark', 'winter': 'dark'}   # (6.4.5)
PLAY_WHEN = [('EverySignIn', 'Every time I log in'),
             ('OncePerDay', 'Once a day, the first time I log in'),
             ('AfterUpdate', 'Only after Ubuntu installs an update'),
             ('FirstTime', "Only once, and again when there's a new video")]
# Quiet hours (4.0): the intro video plays without sound. Off unless the person turns it on.
QUIET_MODES = [('Off', "Don't mute it"),
               ('DoNotDisturb', 'Mute it while Do Not Disturb is on'),
               ('Hours', 'Mute it during these hours')]
DAYS = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
TIMES = ['%02d:%02d' % (h, m) for h in range(24) for m in (0, 15, 30, 45)]
SURPRISE = 'surprise'       # Background: a different one each day. Video: a different one each time.
NAME_MAX = 30
# The only backgrounds people can choose (desktop and lock screen). Backgrounds/<id>.jpg, thumbs/<id>.jpg.
# 6.0.5: in the order of their themed sections (CATEGORIES), and Raccoon is Jimothy (its id stays raccoon, so saved
# choices keep working). 6.1.0: the sections TLA chose, a caption under each default ("Linux default"), and the
# Experimental channel's own background, Battle of the Beta Testers, only on that channel (CHANNEL_ONLY).
BACKGROUNDS = [('microsoft', 'Microsoft'), ('liquid-glass', 'Liquid Glass'), ('penguins', 'Penguins'), ('tla', 'TLA Classic'),
               ('beach', 'Beach'), ('ocean', 'Underwater'), ('rainy', 'Rainy'), ('space', 'Space'), ('vancouver', 'Vancouver'),
               ('frutiger-aero', 'Frutiger Aero'), ('code', 'Code'), ('sky-city', 'Sky City'), ('solarpunk', 'Solarpunk'),
               ('anime', 'Anime'), ('claymation', 'Claymation'), ('pixel', '8-Bit'), ('blocks', 'Blocks'), ('bricks', 'Bricks'),
               ('grumpy-cat', 'Grumpy Cat'), ('bonjovi', 'Bonjovi'), ('raccoon', 'Jimothy'),
               ('experimental', 'Battle of the Beta Testers')]
CATEGORIES = [('defaults', 'Defaults'), ('nature', 'Nature'), ('scifi', 'Sci-Fi'), ('stylized', 'Stylized'), ('animals', 'Animals'),
              ('experimental', 'Experimental channel only'), ('surprise', 'Surprise me')]
CATEGORY_OF = {'microsoft': 'defaults', 'liquid-glass': 'defaults', 'penguins': 'defaults', 'tla': 'defaults',
               'beach': 'nature', 'ocean': 'nature', 'rainy': 'nature', 'space': 'nature', 'vancouver': 'nature',
               'frutiger-aero': 'scifi', 'code': 'scifi', 'sky-city': 'scifi', 'solarpunk': 'scifi',
               'anime': 'stylized', 'claymation': 'stylized', 'pixel': 'stylized', 'blocks': 'stylized', 'bricks': 'stylized',
               'grumpy-cat': 'animals', 'bonjovi': 'animals', 'raccoon': 'animals',
               'experimental': 'experimental', 'surprise': 'surprise'}
CAPTIONS = {'microsoft': 'Windows default', 'liquid-glass': 'macOS default', 'penguins': 'Linux default', 'tla': 'Legacy default',
            'surprise': 'A new one each day'}
CHANNEL_ONLY = {'experimental': 'experimental'}
ANIMALS = [b for b, c in CATEGORY_OF.items() if c == 'animals']
# The intro videos (downloaded to Videos/<id>.mp4, kept only if the SHA-256 matches). 'match' = the video that
# goes with the person's background.
VIDEO_HASHES = {
    'tla':                    '7cb60be851fbcdf6a60176a524c3dee051cca3da8295be3a49cda3927f51fa9b',
    'frutiger-aero':          'b01287343a0b89460dc9c4403fb10ffff79cb61c7b21b6cb03c067656c3895da',   # (4.1: the original again)
    'liquid-glass':           'fd3e3510cad5bfcdd5557bf1050d05b2a2d3452c7ef83ca07bc2c68138cb391f',
    'microsoft':              'd49eea24251e2424af6bed3ca5c33dd4abd2e184ec22aea11f837361697e30e7',
    'rainy':                  '7ae3580eb8bb70a1a692d764bca77a5670ada051262e4b208831c277c32899a7',
    'code':                   '0e8eea44df385807898f8b732aeb804fdd3b14c1d9d169fceebbdb0993f36b02',
    'bricks':                 '0c19192e6e13ef23946055a4593c1abba2dde8cace81408918d5a063c2488afd',   # (4.1: V2)
    'blocks':                 '0ce92e5a85115c42e8cd02cc994914300cd50158e66776e5035e1103cacdb7a3',
    'space':                  '1c9f81b94905fde5dfc765ed09a59b371aef771d4b79a752258c306791ef8db5',
    'claymation':             'dc729567f37032a23aa71d139cb663d22b1e469cb4c66d18bf8021d4fba9f503',
    'anime':                  'b0fc2c29f5305fe57e3617073227a9a8137f18337d5429fa74611f61653bdcaa',
    'penguins':               '2f6f7adbeadbe959e72218b194c0de7ca43d5596a8f67a2c76bd0743ef7434eb',
    'solarpunk':              '725ec78d91c5935963345c60f5b703f36fe017ca40cd47d6501fa956f05d304e',
    'pixel':                  'f9704533e611afbdc1a32d26e8d42bb95b7222e02ea8ecf75c4779d9daf076d3',   # (6.4.5: the new one)
    'ocean':                  '6def8de6af1e729d56d8fa8e224d85d7a7a36993c8e772ff33fa75048020e803',
    'frutiger-aero-v2':       'bbce9fec534928fbae3dbe94e9f5a368f92aba439454ce8882df60fb8cf22460',   # (the 3.4.3 one)
    'liquid-glass-original':  '5dae894482e3cd513baf6214da8a340f9da38ccb7f7589507c39b71bb26afbdf',
    'microsoft-original':     'b781ce6a57156694d5ec85a6dfc6e2521785a7afefcbda2e10a5b985277eb4f8',
    # The seasonal themes' own videos (4.1): played by "Match my background" during the season.
    'fall':                   '9b2828fd96159967445718a8621265781397989135b8021bfeb6c18640fd9767',
    'christmas':              '6f22a687f31f120627804a3db693c0d6b4d7c588b66fdc3c730a1165a29718eb',
    'easter':                 'e68f1b26c63672fcece100904d81c5ad83250d449d45059bc361ac7101482f98',
    'sky-city':               '7d511086c4eaf32fa392034cbe7a981a2896d2796bcad76ee246f00cd72211fc',   # (4.3)
    # Intro videos for the other style (5.0): played instead of the background's own video in that style (5.1.5:
    # Bricks' dark one and Penguins' light one too).
    'blocks-dark':            'c9c6978de5739f27592f385f893102dfa66563fffd2cb66b6015439f3b7c8ce3',
    'frutiger-aero-dark':     '1d1e6210213e3beed4b0d07f7fa2da010d62a235b805051e18d0c5469b9dc255',
    'microsoft-dark':         'f30e43321a61681f3c6749a472fb96be521f99405d5dab56b1aa90003bb43ba8',
    'liquid-glass-dark':      'ce453b6435d599156b8316565ee45d8dde4e98358cbecf41569b686b5d98cf65',
    'bricks-dark':            '74a54c362c24bca8240f6f323df908d79488637ea96a7b9e551b142efdc60f37',   # (5.1.5)
    'penguins-light':         '2efbec474c16367fabd03797e101d30a87fa92d4ee5ec6a3803433add727685b',   # (5.1.5)
    'beach':                  'b5dc48a3c56440d755068a77f6744497f28e85d62e59be51fee6f4fa75412636',   # (5.4)
    'beach-dark':             '431a1396dc5aecd4b1dd0c58e97b2e95adde9658c2f518ef763d5083ed60731f',   # (5.4)
    'anime-dark':             '8a2d221a6639fd6be1000694640647d627b93b89b81d6aaac2c218069a1f780d',   # (5.4; 6.0.5: a new version)
    'pixel-dark':             'b0cfb3db78ba60371f7ee92502bbb6fabc6709ff38d5b6bf562f38f59f0896ce',   # (5.4.5)
    'claymation-dark':        '0970de40e5ff566bc0b354da8200709ae00ce3bf6b8d23dd3072eb3b675cb3bf',   # (5.4.5)
    'solarpunk-dark':         '4c47774ee0d5957e18b69e1c227b7428ca51842943e813085eb11c29d06b5f95',   # (5.6.0)
    'sky-city-dark':          'ad33f57f0ecf7d13dde0366661ca143f8e0f4beb6a53cb707fe81e5ac6705eb3',   # (5.6.0)
    'space-light':            '42b2a456b88441ebed1bb1e53b88a4944b50b600baea23ff445ee696a9fa86d8',   # (5.6.0)
    'ocean-dark':             '04e023547a1f6ed95097235ea95158a5e803bef505b5829c1f25cbcd4873a7e7',   # (5.6.0)
    'grumpy-cat':             '588c9cd54ba08bf1310c02f016967a9485bb240b6375b8844ef8793c92611f0f',   # (5.9.0)
    'grumpy-cat-dark':        '4873ba4d689c05140d42c5f639ae137f11b4a3136fb1575a932885e50fc13109',   # (5.9.0)
    'bonjovi':                '7013cca50dbb60d823e9b38f43dfe00265d4629ade874766d8505495e08650c5',   # (5.9.0)
    'bonjovi-dark':           'd9e9b6c11379d31d345e50ab0435b9ef08628b6ab40ad2f11b2e9fc63755c7d0',   # (5.9.0)
    'code-light':             'e13a4b3c8067f69fe20b15f5178a4a43543c25e37673c0e99e18b9c9eb7eda3b',   # (6.0.5)
    'winter':                 '9e0c57a315e3bc134ee74088083900eebe45917887ac2c7769542e7cd2f8658b',   # (6.4.5)
    'winter-dark':            'c0d80835338478e3179cfe2b74ef42294f13edcb7cec90e0d708a7a4b8d9e291',
}
# 6.0.5: where a video's file in the repository isn't <id>.mp4. A new version of a video goes up under a name of its
# own, so older bundles keep finding the one their list expects.
VIDEO_REMOTE = {'anime-dark': 'anime-dark-v2', 'pixel': 'pixel-v2'}
# 5.6.0: each theme's intro video greets in its own style (greeting.lua draws it; the keys are described in the Mac
# player, player.c). The same table is in the Mac (common.zsh) and Windows (common.ps1) versions. A video without one:
# the classic fade.
GREETING_STYLES = {
    'tla':           'a=line;t0=0.3;d=0.5;e=lin',
    'microsoft':     'a=line;d=0.8;e=out;dy=-0.5;w=semibold',
    'liquid-glass':  'a=line;d=0.9;e=back;sc=0.85;p=glass;w=semibold',
    'penguins':      'a=seq;st=0.035;d=0.7;e=back;dx=-2.5;sh=0B2545B3:0.12:0:-0.04',
    'code':          'a=seq;t0=0.4;st=0.06;d=0;e=step;f=mono;c=4AF626;gl=4AF62699:0.12;p=term;pre=> ;cur=_',
    'frutiger-aero': 'a=line;d=0.9;e=elastic;sc=0.4;f=round;gl=4FD8FF:0.25',
    'solarpunk':     'a=seq;st=0.045;d=0.6;e=back;sy=0;an=b;c=FFFBEA;gl=7BD389:0.22',
    'rainy':         'a=seq;st=0.05;d=0.65;e=bounce;dy=2.2;c=DCEBFF;sh=0A1A33B3:0.1:0:-0.04',
    'space':         'a=rand;st=0.05;d=1.0;e=out;sc=2.2;ls=0.1;gl=B28DFF:0.3',
    'ocean':         'a=seq;st=0.05;d=1.1;e=out;dy=-1.6;bob=0.06;bp=2.4;c=B8F3FF;gl=0096C8:0.22',
    'beach':         'a=seq;st=0.05;d=0.7;e=out;dy=-0.6;bob=0.09;bp=1.8;c=FFF1C9;sh=B4462899:0.12:0:-0.04',
    'claymation':    'a=seq;st=0.065;d=0.7;e=elastic;sx=1.5;sy=0.3;an=b;f=round;w=heavy;c=FFB347;sh=5A2D0C:0:0.05:-0.06',
    'blocks':        'a=seq;st=0.07;d=0.7;e=bounce;dy=3;w=heavy;c=FF5A5A,FFD93D,5BD66B,4DA6FF;sh=000000B3:0:0.05:-0.05',
    'bricks':        'a=seq;st=0.075;d=0.35;e=out;sc=2.2;an=b;w=heavy;sh=B23A1E:0:0.06:-0.06',
    'pixel':         'a=seq;st=0.06;d=0;e=step;f=mono;c=FFD93D;sh=000000:0:0.07:-0.07;x=step',
    'anime':         'a=line;t0=0.25;d=0.45;e=back;sc=2.6;r=-6;it=1;w=heavy;gl=FF5FA2:0.12',
    'sky-city':      'a=line;d=1.6;e=out;dy=1.2;bob=0.05;bp=3.2;gl=7EC8FFCC:0.25',
    'grumpy-cat':    'a=line;t0=0.6;d=1.4;e=lin;dy=0.3;c=DCE6F2;sh=0A1220B3:0.12:0:-0.04;x=drop',
    'bonjovi':       'a=seq;st=0.06;d=0.6;e=bounce;dy=2.4;f=round;w=bold;c=FFD54A;sh=1B2A6BB3:0.1:0:-0.04',
    'winter':        'a=seq;st=0.055;d=0.9;e=out;dy=1.4;c=EAF7FF;gl=9FD8FF:0.3;sh=0A1A33B3:0.1:0:-0.04',
}
# Other versions of some videos, still there for anyone who prefers them: Frutiger Aero's newer video (4.1: its
# original is the main one again), and the originals of Liquid Glass and Microsoft.
ORIGINAL_VIDEOS = [('frutiger-aero-v2', 'Frutiger Aero (newer version)'), ('liquid-glass-original', 'Liquid Glass (original)'),
                   ('microsoft-original', 'Microsoft (original)')]
# 4.1: an earlier choice of Frutiger Aero's original keeps it (it's "Frutiger Aero" again).
ALIASES = {('Video', 'frutiger-aero-original'): 'frutiger-aero'}
VIDEOS = ([('match', 'Match my background'), (SURPRISE, 'Surprise me (a different one each time)')] +
          [(i, n) for i, n in BACKGROUNDS if i in VIDEO_HASHES] + ORIGINAL_VIDEOS)
# Seasonal themes (4.0): during its season, everyone still on the organization's default background gets the
# seasonal one instead (desktop and lock screen). Picking any background yourself keeps yours. They aren't in the
# picker. 4.1: they have their own intro videos (the default background's plays until it's downloaded).
SEASONAL = [('fall', 'Fall'), ('christmas', 'Christmas'), ('easter', 'Easter'), ('winter', 'Winter')]   # (6.4.5: Winter)
SEASON_ENDS = {'fall': 'November 30', 'christmas': 'January 6', 'easter': 'Easter Monday', 'winter': 'March 19'}
BG_NAMES = dict(BACKGROUNDS + SEASONAL + [(SURPRISE, 'Surprise me')])


# ---- settings ---------------------------------------------------------------------------------------------------
def config_dir():
    d = os.path.join(os.environ.get('XDG_CONFIG_HOME') or os.path.expanduser('~/.config'), 'tla-bootpaper')
    os.makedirs(d, exist_ok=True)
    return d


def read_json(path):
    try:
        with open(path) as f:
            v = json.load(f)
            return v if isinstance(v, dict) else {}
    except Exception:
        return {}


def write_json(path, data):
    tmp = path + '.tmp'
    with open(tmp, 'w') as f:
        json.dump(data, f, indent=1)
    os.replace(tmp, path)


def valid(name, value):
    if name == 'PlayWhen':
        return value in [p for p, _ in PLAY_WHEN]
    if name == 'Background':
        return value in dict(BACKGROUNDS) or value == SURPRISE or own_picture_valid(value)
    if name == 'Video':
        return value in [v for v, _ in VIDEOS]
    if name == 'QuietMode':
        return value in [q for q, _ in QUIET_MODES]
    if name in ('QuietStart', 'QuietEnd'):
        return value in TIMES
    if name == 'QuietDays':
        return isinstance(value, str) and all(d in DAYS for d in value.split(',') if d)
    if name == 'PreferredName':
        return isinstance(value, str) and len(value) <= NAME_MAX and value.isprintable()
    if name == 'WallpaperFit':
        return value in [f for f, _, _ in FITS]
    if name == 'TempBackground':
        return value in dict(BACKGROUNDS) or own_picture_valid(value)
    if name == 'TempUntil':
        return isinstance(value, str) and re.fullmatch(r'\d{4}-\d{2}-\d{2}', value) is not None
    if name == 'Channel':
        return value in dict(CHANNELS)
    if name == 'LightDark':
        return value in dict(LIGHT_DARK)
    return value in (0, 1)


def org(name):
    v = read_json(ORG_FILE).get(name)
    if isinstance(v, bool):
        v = int(v)
    return v if (name == 'UsersCanChange' and v in (0, 1)) or valid(name, v) else DEFAULTS[name]


def users_can_change():
    return org('UsersCanChange') != 0


def mine():
    return read_json(os.path.join(config_dir(), 'settings.json'))


def setting(name):
    """The value in effect for this person. (4.3: a background or video they picked that isn't out on their
    release channel, e.g. after leaving Experimental, counts as not picked. 5.7.0: until they sign in, TLA Classic and
    the organization's settings; their release channel still counts, since that decides whether they need to.)"""
    if name != 'Channel' and signed_out():
        return 'tla' if name in ('Background', 'Video') else org(name)
    if users_can_change():
        v = mine().get(name)
        v = ALIASES.get((name, v), v)
        if valid(name, v) and (name not in ('Background', 'Video', 'TempBackground') or released(v)):
            return v
    return org(name)


# ---- release channels (4.3) -------------------------------------------------------------------------------------
def vkey(v):
    """'4.3' -> (4, 3, 0, 0), so '4.3' == '4.3.0' and '4.2.5' < '4.3'. None if it isn't a version."""
    if not isinstance(v, str) or not re.fullmatch(r'\d{1,4}(\.\d{1,4}){0,3}', v):
        return None
    p = [int(x) for x in v.split('.')] + [0, 0, 0]
    return tuple(p[:4])


def channel():
    return setting('Channel')


def channel_release(ch=None):
    """The newest release on a channel (this person's by default). Experimental always has at least Stable's."""
    ch = ch or channel()
    marks = dict(CHANNEL_MARKS)
    for k, v in read_json(CHANNELS_FILE).items():
        if k in marks and vkey(v):
            marks[k] = v
    if ch == 'experimental' and vkey(marks['experimental']) < vkey(marks['stable']):
        return marks['stable']
    return marks.get(ch, marks['stable'])


def shown_release():
    """The version this person sees: their channel's release, or this bundle's if that's older."""
    r = channel_release()
    return r if vkey(r) < vkey(RELEASE) else RELEASE


def release_label(v):
    return 'Experimental' if vkey(v) > vkey(channel_release('stable')) else 'Stable'


def released(thing):
    """True when something (a background, video or feature, by id) is out on this person's channel."""
    if thing in CHANNEL_ONLY:       # (6.1.0: only ever on that channel)
        return channel() == CHANNEL_ONLY[thing]
    return thing not in SINCE or vkey(SINCE[thing]) <= vkey(channel_release())


def version_summary():
    shown = shown_release()
    return '%s (%s)%s' % (shown, dict(CHANNELS)[channel()], '' if shown == RELEASE else ', %s installed' % RELEASE)


def sync_channels():
    """The guard, every 15 minutes: which release is on each channel, from channels.json on GitHub. Only version
    numbers are taken from it. Offline, the last ones stay."""
    try:
        data = json.loads(urllib.request.urlopen(CHANNELS_URL, timeout=30).read().decode('utf-8'))
        marks = {k: str(data.get(k, '')).strip() for k in ('stable', 'experimental')}
        if not all(vkey(v) for v in marks.values()):
            raise ValueError("it doesn't look right")
    except Exception as e:
        log("Couldn't read the release channels (%s)." % e)
        return
    if read_json(CHANNELS_FILE) != marks:
        write_json(CHANNELS_FILE, marks)
        os.chmod(CHANNELS_FILE, 0o644)
        log('Release channels: stable %s, experimental %s.' % (marks['stable'], marks['experimental']))

# ---- Hub sign-in (5.7.0) ------------------------------------------------------------------------------------------
# Everyone signs in with their Hub account (through Google until the Hub's own page is ready). Until they do, the app's
# settings are greyed out and they get TLA Classic. A sign-in lasts a month (validDays): they can sign in again in its
# last week (renewDays), get reminders 7 and 3 days before (remindDays), and 3 extra days if it runs out while the
# computer is offline (graceDays). auth.json on GitHub switches it on and says how (the guard fetches it as root, with
# the keys that sign-ins are checked against, into SIGNIN_DIR: people can't write there). Their own sign-in is in
# ~/.config/tla-bootpaper/signin.json; anyone could edit that file, which is why it's checked every time.
AUTH_URL = 'https://raw.githubusercontent.com/ebuskell-source/Default-wallpaper/main/TLA-BootPaper/auth.json'
SIGNIN_PAGE = 'https://ebuskell-source.github.io/Default-wallpaper/TLA-BootPaper/signin/'
GOOGLE_CERTS = 'https://www.googleapis.com/oauth2/v3/certs'

SIGNIN_DEFAULTS = {'required': False, 'provider': 'google', 'validDays': 30, 'renewDays': 7, 'graceDays': 3,
                   'remindDays': [7, 3]}
SHA256_INFO = bytes.fromhex('3031300d060960864801650304020105000420')
GOOGLE_ISSUERS = ('https://accounts.google.com', 'accounts.google.com')
HUB_AUDIENCE = 'tla-bootpaper'


def b64u_dec(s):
    s = str(s)
    if not all(c.isalnum() or c in '-_' for c in s):
        raise ValueError('not base64url')
    return base64.urlsafe_b64decode(s + '=' * (-len(s) % 4))


def b64u_enc(b):
    return base64.urlsafe_b64encode(b).rstrip(b'=').decode()


def signin_config(raw):
    """auth.json, with anything missing or out of range set to its default."""
    c = dict(SIGNIN_DEFAULTS)
    raw = raw if isinstance(raw, dict) else {}
    num = lambda k, lo, hi: raw[k] if isinstance(raw.get(k), int) and not isinstance(raw.get(k), bool) and lo <= raw[k] <= hi else c[k]
    c['required'] = raw.get('required') is True
    c['provider'] = raw.get('provider') if raw.get('provider') in ('hub', 'google') else 'google'
    c['validDays'] = num('validDays', 1, 120)
    c['renewDays'] = min(num('renewDays', 0, 60), c['validDays'])
    c['graceDays'] = num('graceDays', 0, 14)
    rd = raw.get('remindDays')
    c['remindDays'] = sorted({d for d in rd if isinstance(d, int) and 0 < d <= 60}, reverse=True) if isinstance(rd, list) else [7, 3]
    g = raw.get('google') if isinstance(raw.get('google'), dict) else {}
    h = raw.get('hub') if isinstance(raw.get('hub'), dict) else {}
    s = lambda d, k: d.get(k).strip() if isinstance(d.get(k), str) else ''
    c['google'] = {'clientId': s(g, 'clientId'),
                   'domains': [d.lower() for d in g.get('domains', []) if isinstance(d, str) and d] if isinstance(g.get('domains'), list) else []}
    c['hub'] = {'signInUrl': s(h, 'signInUrl'), 'issuer': s(h, 'issuer'), 'jwksUrl': s(h, 'jwksUrl')}
    return c


def signin_kinds(c):
    """Which sign-ins are accepted: Google's while a client id is set, the Hub's once its issuer and keys are."""
    k = []
    if c['google']['clientId'] and c['google']['domains']:
        k.append('google')
    if c['hub']['issuer'] and c['hub']['jwksUrl'] and c['hub']['signInUrl'].startswith('https://'):
        k.append('hub')
    return k


def signin_required(c):
    return bool(c['required'] and signin_kinds(c))


def signin_nonce(device, user, salt):
    return b64u_enc(hashlib.sha256(('tla-bootpaper/1\n%s\n%s\n%s' % (device, user, salt)).encode()).digest())


def rs256_valid(jwk, signing_input, sig):
    try:
        n = int.from_bytes(b64u_dec(jwk['n']), 'big')
        e = int.from_bytes(b64u_dec(jwk['e']), 'big')
    except Exception:
        return False
    k = (n.bit_length() + 7) // 8
    if k < 256 or len(sig) != k or e < 3:            # 2048-bit keys or bigger
        return False
    s = int.from_bytes(sig, 'big')
    if s >= n:
        return False
    m = pow(s, e, n).to_bytes(k, 'big')
    t = SHA256_INFO + hashlib.sha256(signing_input).digest()
    want = b'\x00\x01' + b'\xff' * (k - len(t) - 3) + b'\x00' + t
    return hmac.compare_digest(m, want)


def signin_check(token, c, keys, device, user, salt, now, fresh=False):
    """(True, info) for a good token, else (False, reason). fresh: just handed back by the sign-in page."""
    try:
        h64, p64, s64 = str(token).split('.')
        hdr = json.loads(b64u_dec(h64))
        body = json.loads(b64u_dec(p64))
        sig = b64u_dec(s64)
    except Exception:
        return False, 'invalid'
    if not isinstance(hdr, dict) or not isinstance(body, dict) or hdr.get('alg') != 'RS256' or not isinstance(hdr.get('kid'), str):
        return False, 'invalid'
    iss = body.get('iss')
    kinds = signin_kinds(c)
    if iss in GOOGLE_ISSUERS and 'google' in kinds:
        kind = 'google'
    elif iss == c['hub']['issuer'] and 'hub' in kinds:
        kind = 'hub'
    else:
        return False, 'invalid'
    jwk = next((k for k in keys if k.get('kind') == kind and k.get('kid') == hdr['kid']), None)
    if jwk is None:
        return False, 'pending'                        # a key root hasn't fetched yet (or a made-up one)
    if not rs256_valid(jwk, (h64 + '.' + p64).encode(), sig):
        return False, 'invalid'
    if kind == 'google':
        if body.get('aud') != c['google']['clientId'] or body.get('email_verified') is not True or \
                str(body.get('hd', '')).lower() not in c['google']['domains']:
            return False, 'invalid'
    elif body.get('aud') != HUB_AUDIENCE:
        return False, 'invalid'
    if not isinstance(salt, str) or not salt or body.get('nonce') != signin_nonce(device, user, salt):
        return False, 'invalid'
    iat, exp = body.get('iat'), body.get('exp')
    if not isinstance(iat, int) or isinstance(iat, bool) or iat > now + 86400:
        return False, 'invalid'
    if fresh and (abs(now - iat) > 600 or not isinstance(exp, int) or exp < now - 300):
        return False, 'stale'
    who = body.get('email') if kind == 'google' else body.get('username')
    return True, {'kind': kind, 'iat': iat, 'name': str(body.get('name') or who or '')[:80], 'who': str(who or '')[:120]}


def signin_status(c, keys, token, salt, device, user, now, online=None):
    """{'state': off|in|renew|grace|out, ...}. online: a function, asked only in the grace days."""
    if not signin_required(c):
        return {'state': 'off'}
    if not token:
        return {'state': 'out', 'reason': 'none'}
    ok, info = signin_check(token, c, keys, device, user, salt, now)
    if not ok:
        return {'state': 'out', 'reason': info}
    until = info['iat'] + c['validDays'] * 86400
    st = dict(info, until=until)
    if now < until:
        st['days'] = math.ceil((until - now) / 86400)
        st['state'] = 'renew' if st['days'] <= c['renewDays'] else 'in'
    elif now < until + c['graceDays'] * 86400 and online is not None and online() is False:
        st['state'] = 'grace'
        st['days'] = math.ceil((until + c['graceDays'] * 86400 - now) / 86400)
    else:
        st['state'] = 'out'
        st['reason'] = 'expired'
    return st


def signin_merge_keys(old, fetched, now, keep_days=60):
    """Root's key list: what it has seen, each kept for keep_days after it was last published."""
    out = {}
    for k in old if isinstance(old, list) else []:
        if isinstance(k, dict) and k.get('kind') in ('hub', 'google') and isinstance(k.get('kid'), str) and \
                isinstance(k.get('last'), int) and now - k['last'] < keep_days * 86400:
            out[(k['kind'], k['kid'])] = {x: k[x] for x in ('kind', 'kid', 'n', 'e', 'first', 'last') if x in k}
    for kind, jwks in fetched:
        for j in (jwks or {}).get('keys', []) if isinstance(jwks, dict) else []:
            if not isinstance(j, dict) or j.get('kty') != 'RSA' or j.get('alg', 'RS256') != 'RS256' or \
                    not isinstance(j.get('kid'), str) or not isinstance(j.get('n'), str) or not isinstance(j.get('e'), str):
                continue
            first = out.get((kind, j['kid']), {}).get('first', now)
            out[(kind, j['kid'])] = {'kind': kind, 'kid': j['kid'][:200], 'n': j['n'], 'e': j['e'], 'first': first, 'last': now}
    return sorted(out.values(), key=lambda k: -k['last'])[:40]


def signin_dir():
    """Where root keeps auth.json and the keys (in the app's own folder when it's installed just for one person)."""
    return '/etc/tla-bootpaper/signin' if installed_for_everyone() else os.path.join(APP_DIR, 'signin')


def signin_settings():
    return signin_config(read_json(os.path.join(signin_dir(), 'auth.json')))


def signin_keys():
    k = read_json(os.path.join(signin_dir(), 'keys.json')).get('keys')
    return k if isinstance(k, list) else []


def signin_device():
    return 'linux:' + (read_text('/etc/machine-id').strip() or platform.node())


def signin_user():
    return pwd.getpwuid(os.getuid()).pw_name


def signin_mine():
    return read_json(os.path.join(config_dir(), 'signin.json'))


def signin_online():
    """Can this computer reach the sign-in page? (Asked only when a sign-in has run out, for the grace days; the
    answer is kept for 10 minutes.)"""
    st = state()
    chk = st.get('OnlineCheck') if isinstance(st.get('OnlineCheck'), dict) else {}
    if isinstance(chk.get('at'), (int, float)) and 0 <= time.time() - chk['at'] < 600:
        return bool(chk.get('ok'))
    try:
        urllib.request.urlopen(urllib.request.Request(SIGNIN_PAGE, method='HEAD'), timeout=5).close()
        ok = True
    except urllib.error.HTTPError:
        ok = True                         # (an answer of any kind means it's online)
    except Exception:
        ok = False
    set_state(OnlineCheck={'at': int(time.time()), 'ok': ok})
    return ok


_SIGNIN = {}


def signin_now(fresh=False):
    """This person's sign-in: {'state': 'off'|'in'|'renew'|'grace'|'out', ...} (worked out once per run)."""
    if fresh or 'st' not in _SIGNIN:
        if os.geteuid() == 0 or not released('signin'):
            _SIGNIN['st'] = {'state': 'off'}
        else:
            m = signin_mine()
            _SIGNIN['st'] = signin_status(signin_settings(), signin_keys(), m.get('token') or '', m.get('salt') or '',
                                          signin_device(), signin_user(), int(time.time()), online=signin_online)
    return _SIGNIN['st']


def signed_out():
    """True while this person has to sign in first: their settings don't apply, and they get TLA Classic."""
    return signin_now()['state'] == 'out'


def signin_save(token, salt):
    write_json(os.path.join(config_dir(), 'signin.json'), {'token': token, 'salt': salt})
    os.chmod(os.path.join(config_dir(), 'signin.json'), 0o600)
    signin_now(fresh=True)


def signin_forget():
    try:
        os.remove(os.path.join(config_dir(), 'signin.json'))
    except OSError:
        pass
    signin_now(fresh=True)


def signin_fetch_json(url, timeout=20):
    data = json.loads(urllib.request.urlopen(url, timeout=timeout).read().decode('utf-8'))
    if not isinstance(data, dict):
        raise ValueError("it isn't a JSON object")
    return data


def signin_live_keys(c):
    """The keys as published right now (the app, to check a sign-in the moment it comes back)."""
    fetched = []
    if c['google']['clientId']:
        try:
            fetched.append(('google', signin_fetch_json(GOOGLE_CERTS)))
        except Exception as e:
            log("Sign-in: couldn't get Google's keys (%s)." % e)
    if c['hub']['jwksUrl'].startswith('https://'):
        try:
            fetched.append(('hub', signin_fetch_json(c['hub']['jwksUrl'])))
        except Exception as e:
            log("Sign-in: couldn't get the Hub's keys (%s)." % e)
    return fetched


def sync_signin(force=False):
    """The guard (root, or the person when it's installed just for them): auth.json and the keys, every 6 hours, or
    right away when the app asks (a sign-in it couldn't finish yet because of a new key). Offline, what's there stays."""
    d = signin_dir()
    stamp = os.path.join(d, '.checked')
    try:
        age = time.time() - os.path.getmtime(stamp)
    except OSError:
        age = 1e9
    if age < (60 if force else 6 * 3600):
        return
    os.makedirs(d, exist_ok=True)
    os.chmod(d, 0o755)
    open(stamp, 'w').close()
    try:
        raw = signin_fetch_json(AUTH_URL + '?t=%d' % time.time())
        if read_json(os.path.join(d, 'auth.json')) != raw:
            log('Sign-in settings: %s.' % ('required' if signin_required(signin_config(raw)) else 'not required'))
        write_json(os.path.join(d, 'auth.json'), raw)
        os.chmod(os.path.join(d, 'auth.json'), 0o644)
    except Exception as e:
        log("Couldn't read the sign-in settings (%s)." % e)
    c = signin_settings()
    fetched = signin_live_keys(c)
    old = signin_keys()
    keys = signin_merge_keys(old, fetched, int(time.time()))
    if keys != old or not os.path.exists(os.path.join(d, 'keys.json')):
        write_json(os.path.join(d, 'keys.json'), {'keys': keys, 'updated': int(time.time())})
        os.chmod(os.path.join(d, 'keys.json'), 0o644)


def signin_when(epoch):
    return datetime.datetime.fromtimestamp(epoch).strftime('%A, %B %-d')


def signin_remind():
    """A few seconds after login: "sign in again" 7 and 3 days before a sign-in runs out (once each), and, for someone
    who isn't signed in, a note at most once a week. With a "Sign in" button where notifications have buttons."""
    time.sleep(20)
    st, c = signin_now(), signin_settings()
    if st['state'] == 'off':
        return
    rec = state().get('SignInReminded') if isinstance(state().get('SignInReminded'), dict) else {}
    title = body = ''
    if st['state'] in ('in', 'renew'):
        due = [d for d in c['remindDays'] if st['days'] <= d]
        done = rec.get('days', []) if rec.get('iat') == st['iat'] else []
        if due and min(due) not in done:
            set_state(SignInReminded={'iat': st['iat'], 'days': sorted(set(done) | set(due))})
            title = 'Time to sign in to TLA BootPaper again'
            body = ('Your sign-in runs out %s (%s). Sign in again with your Hub account to keep your video and '
                    'background.' % ('tomorrow' if st['days'] <= 1 else 'in %d days' % st['days'], signin_when(st['until'])))
    elif st['state'] == 'grace':
        if rec.get('grace') != today().isoformat():
            set_state(SignInReminded=dict(rec, grace=today().isoformat()))
            title = 'Sign in to TLA BootPaper when you’re back online'
            body = ('Your sign-in has run out. You have %d more day%s to sign in again with your Hub account.'
                    % (st['days'], '' if st['days'] == 1 else 's'))
    elif st['state'] == 'out':
        last = rec.get('out', '')
        if not last or (today() - datetime.date.fromisoformat(last)).days >= 7:
            set_state(SignInReminded=dict(rec, out=today().isoformat()))
            title = 'Sign in to TLA BootPaper'
            body = ('Sign in with your Hub account to choose your welcome video and background. Until then you’ll '
                    'see TLA Classic.')
    if not title:
        return
    icon = os.path.join(APP_DIR, 'AppIcon.png')
    clicked = ''
    try:
        r = subprocess.run(['notify-send', '--app-name=TLA BootPaper', '--icon=' + icon, '--action=signin=Sign in',
                            '--wait', '--expire-time=60000', title, body], capture_output=True, text=True, timeout=120)
        if r.returncode != 0:
            raise OSError(r.stderr.strip())
        clicked = r.stdout.strip()
    except Exception:
        notify(title, body + ' Open TLA BootPaper from Activities to sign in.')
    if clicked == 'signin':
        subprocess.Popen([sys.executable, os.path.abspath(__file__), 'app', '--signin'], start_new_session=True)


class SignInListener:
    """The app's side of signing in: waits on 127.0.0.1 for the sign-in page to hand back the token (at most 10
    minutes), then sends the browser on to the "you're all set" page. done(query) gets what came back."""

    def __init__(self, done):
        import socket
        self.done = done
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.sock.bind(('127.0.0.1', 0))
        self.sock.listen(8)
        self.sock.setblocking(False)
        self.port = self.sock.getsockname()[1]
        self.until = time.time() + 600

    def poll(self):
        """Called every 200 ms. False once it's finished (or given up)."""
        import socket
        from urllib.parse import urlsplit, parse_qs
        if self.sock is None:
            return False
        if time.time() > self.until:
            self.close()
            self.done(None)
            return False
        while True:
            try:
                conn, _ = self.sock.accept()
            except (BlockingIOError, InterruptedError):
                return True
            except OSError:
                self.close()
                self.done(None)
                return False
            try:
                conn.settimeout(3)
                data = b''
                while b'\r\n\r\n' not in data and len(data) < 32768:
                    chunk = conn.recv(4096)
                    if not chunk:
                        break
                    data += chunk
                line = data.split(b'\r\n', 1)[0].decode('latin-1').split(' ')
                path = line[1] if len(line) >= 2 and line[0] == 'GET' else ''
                if path.startswith('/callback?'):
                    conn.sendall(b'HTTP/1.1 302 Found\r\nLocation: ' + (SIGNIN_PAGE + '?done=1').encode() +
                                 b'\r\nContent-Length: 0\r\nConnection: close\r\n\r\n')
                    q = {k: v[0] for k, v in parse_qs(urlsplit(path).query).items()}
                    conn.close()
                    self.close()
                    self.done(q)
                    return False
                conn.sendall(b'HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\nConnection: close\r\n\r\n')
            except (OSError, socket.timeout):
                pass
            finally:
                try:
                    conn.close()
                except OSError:
                    pass

    def close(self):
        if self.sock is not None:
            self.sock.close()
            self.sock = None


def signin_begin(port):
    """Starts signing in: a new salt (it goes into the nonce, which ties the sign-in to this computer and this account)
    and state (which says where the app is listening), and the address to open in the browser."""
    import secrets
    from urllib.parse import urlencode
    salt = b64u_enc(secrets.token_bytes(16))
    st = '%d.%s' % (port, b64u_enc(secrets.token_bytes(16)))
    nonce = signin_nonce(signin_device(), signin_user(), salt)
    return {'salt': salt, 'state': st, 'started': int(time.time()),
            'url': SIGNIN_PAGE + '?' + urlencode({'state': st, 'nonce': nonce, 'v': '1'})}


def signin_finish(pend, q):
    """What came back from the sign-in page: (True, message) once it's saved, (False, message) if not."""
    if not q:
        return False, 'Signing in took too long. Try again.'
    if q.get('state') != pend.get('state'):
        return False, 'That sign-in was for another window. Try again.'
    if q.get('error') or not q.get('token'):
        return False, ('Your Hub account can’t be used for TLA BootPaper.' if q.get('error') == 'not_eligible'
                       else 'Signing in didn’t finish. Try again.')
    c, now = signin_settings(), int(time.time())
    token, salt = q['token'][:8192], pend['salt']
    ok, info = signin_check(token, c, signin_keys(), signin_device(), signin_user(), salt, now, fresh=True)
    if not ok and info == 'pending':
        # A key root hasn't fetched yet: check it against the keys as published right now, then ask root for them.
        ok, info = signin_check(token, c, signin_merge_keys([], signin_live_keys(c), now), signin_device(),
                                signin_user(), salt, now, fresh=True)
        if ok and not installed_for_everyone():
            sync_signin(force=True)
        elif ok:
            care_request('signin')
    if not ok:
        log('Sign-in: not accepted (%s).' % info)
        return False, ('Your computer’s clock looks wrong, or the sign-in took too long. Check the date and time, then '
                       'try again.' if info == 'stale' else 'That sign-in couldn’t be checked. Try again.')
    signin_save(token, salt)
    log('Signed in as %s (%s).' % (info['who'], info['kind']))
    return True, 'Signed in as %s.' % (info['name'] or info['who'])


def save(name, value):
    """Saves a choice. Matching the organization default removes it, so later default changes still apply.
    A background picked in the app is always kept (even the default one): it's what tells the seasonal themes
    this person chose their own."""
    s = mine()
    if value == org(name) and name != 'Background':
        s.pop(name, None)
    else:
        s[name] = value
    write_json(os.path.join(config_dir(), 'settings.json'), s)


def state():
    return read_json(os.path.join(config_dir(), 'state.json'))


def set_state(**kw):
    s = state()
    s.update(kw)
    write_json(os.path.join(config_dir(), 'state.json'), s)


def log(text):
    path = os.path.join(config_dir(), 'tla-bootpaper.log') if os.geteuid() else LOG_FILE
    try:
        if os.path.exists(path) and os.path.getsize(path) > 65536:
            os.replace(path, path + '.old')
        with open(path, 'a') as f:
            f.write(time.strftime('%Y-%m-%d %H:%M:%S ') + text + '\n')
    except Exception:
        pass


# ---- backgrounds ------------------------------------------------------------------------------------------------
# 5.9.5: Microsoft and Liquid Glass in 4K, under new file names ("<id>-r6.jpg", "<id>-<style>-r6.jpg") so GNOME
# shows the new pictures (it keeps showing a picture it already has under the same name).
PICTURE_REVISIONS = {'microsoft': 'r6', 'liquid-glass': 'r6', 'pixel': 'r3'}   # (6.4.5: 8-Bit's new pictures)


def background_path(bg_id, style=None):
    """The picture of a background; with style ('light' or 'dark', 5.0), that style's own picture where it has one.
    (5.9.0: one of their own pictures is the same in both.)"""
    if is_own(bg_id):
        return own_path(bg_id)
    rev = '-' + PICTURE_REVISIONS[bg_id] if bg_id in PICTURE_REVISIONS else ''
    if style and VARIANTS.get(bg_id) == style:
        p = os.path.join(APP_DIR, 'Backgrounds', '%s-%s%s.jpg' % (bg_id, style, rev))
        if os.path.exists(p):
            return p
    return os.path.join(APP_DIR, 'Backgrounds', bg_id + rev + '.jpg')


def thumb_path(bg_id, style=None):
    if is_own(bg_id):
        return own_path(bg_id)
    if style and VARIANTS.get(bg_id) == style:
        p = os.path.join(APP_DIR, 'Backgrounds', 'thumbs', '%s-%s.jpg' % (bg_id, style))
        if os.path.exists(p):
            return p
    return os.path.join(APP_DIR, 'Backgrounds', 'thumbs', bg_id + '.jpg')


def bg_name(bg_id):
    """A background's name, for people (5.9.0: and "Your picture" for one of their own)."""
    return 'Your picture' if is_own(bg_id) else BG_NAMES.get(bg_id, bg_id)


# ---- their own pictures (5.9.0) ---------------------------------------------------------------------------------
# On a computer that belongs to the person rather than to TLA, they can add pictures of their own in the app: the
# desktop and lock screen then show that, and it's still only changed in the app (the guard puts it back if it's
# changed in Settings). TLA's laptops have TLA BootPaper installed for everyone (/opt: Intune runs the script as
# root); installed for just one person, it's their own computer. The organization can decide instead: "OwnPictures":
# 1 (every computer) or 0 (none) in org-defaults.json. Out on Experimental first.
# Each picture is a JPEG copy the app makes when it's added: ~/.local/share/tla-bootpaper-pictures/own-<8 hex>.jpg
# (the id is the start of that copy's SHA-256). Outside the app's own folder, so updates (and an install for
# everyone, which removes the one-person installs) keep them. At most OWN_MAX of them.
OWN_MAX = 12
OWN_MIN_SIZE = 200          # (pixels, each way: anything smaller would just be a blur on the screen)
OWN_MAX_SIZE = 3840         # (the longer side of the copy; bigger pictures are scaled down)


def is_own(bg_id):
    return isinstance(bg_id, str) and re.fullmatch(r'own-[0-9a-f]{8}', bg_id) is not None


def own_pictures_allowed():
    if not released('ownpictures') or not users_can_change():
        return False
    v = read_json(ORG_FILE).get('OwnPictures')
    if v in (0, 1):                   # (True and False too)
        return bool(v)
    return not installed_for_everyone()


def own_dir():
    return os.path.join(os.environ.get('XDG_DATA_HOME') or os.path.expanduser('~/.local/share'),
                        'tla-bootpaper-pictures')


def own_path(bg_id):
    return os.path.join(own_dir(), bg_id + '.jpg')


def own_picture_valid(bg_id):
    return is_own(bg_id) and own_pictures_allowed() and os.path.isfile(own_path(bg_id))


def own_pictures():
    """Their pictures' ids, oldest first."""
    try:
        names = os.listdir(own_dir())
    except OSError:
        return []
    ids = [n[:-4] for n in names if n.endswith('.jpg') and is_own(n[:-4])]
    return sorted(ids, key=lambda i: (os.path.getmtime(own_path(i)), i))


def own_add(src):
    """Adds a picture (most kinds: JPEG, PNG, WebP, HEIC where Ubuntu can open it): a JPEG copy, turned the right way
    up and at most OWN_MAX_SIZE across. Returns (its id, '') or ('', what went wrong, for people)."""
    if len(own_pictures()) >= OWN_MAX:
        return '', 'You can have up to %d pictures. Remove one to add another.' % OWN_MAX
    import gi
    gi.require_version('GdkPixbuf', '2.0')
    from gi.repository import GdkPixbuf
    try:
        pb = GdkPixbuf.Pixbuf.new_from_file(src)
        pb = pb.apply_embedded_orientation() or pb
    except Exception:
        return '', "That picture couldn't be used. Try a JPEG or PNG picture."
    w, h = pb.get_width(), pb.get_height()
    if w < OWN_MIN_SIZE or h < OWN_MIN_SIZE:
        return '', 'That picture is too small. Try a bigger one.'
    f = min(1.0, OWN_MAX_SIZE / max(w, h))
    nw, nh = max(1, round(w * f)), max(1, round(h * f))
    # (onto white, so a see-through picture doesn't come out black)
    out = GdkPixbuf.Pixbuf.new(GdkPixbuf.Colorspace.RGB, False, 8, nw, nh)
    out.fill(0xffffffff)
    pb.composite(out, 0, 0, nw, nh, 0, 0, nw / w, nh / h, GdkPixbuf.InterpType.HYPER, 255)
    os.makedirs(own_dir(), exist_ok=True)
    fd, tmp = tempfile.mkstemp(prefix='.add-', suffix='.jpg', dir=own_dir())
    os.close(fd)
    try:
        out.savev(tmp, 'jpeg', ['quality'], ['90'])
        bg_id = 'own-' + sha256(tmp)[:8]
        if os.path.exists(own_path(bg_id)):
            os.remove(tmp)                # (added before: that one stays, in its place)
        else:
            os.chmod(tmp, 0o600)
            os.replace(tmp, own_path(bg_id))
    except Exception as e:
        try:
            os.remove(tmp)
        except OSError:
            pass
        log("Couldn't add a picture of their own (%s)." % e)
        return '', "That picture couldn't be saved. Check there's space on this computer, then try again."
    log('Added a picture of their own (%s).' % bg_id)
    return bg_id, ''


def own_remove(bg_id):
    """Removes one of their pictures (the one they added it from stays where it was). If it's their background, or
    their pick for a while, that goes back to the organization's."""
    if not is_own(bg_id):
        return
    m = mine()
    if bg_id in (m.get('Background'), m.get('TempBackground')):
        for k in (['Background'] if m.get('Background') == bg_id else []) + (
                ['TempBackground', 'TempUntil'] if m.get('TempBackground') == bg_id else []):
            m.pop(k, None)
        write_json(os.path.join(config_dir(), 'settings.json'), m)
    try:
        os.remove(own_path(bg_id))
        log('Removed a picture of their own (%s).' % bg_id)
    except OSError:
        pass


# ---- light and dark (5.0) ---------------------------------------------------------------------------------------
def system_style():
    """GNOME's style right now (Settings > Appearance): 'dark' or 'light'. TLA_STYLE overrides it, for testing."""
    v = os.environ.get('TLA_STYLE') or gsettings('get', 'org.gnome.desktop.interface', 'color-scheme').strip("'")
    return 'dark' if v in ('dark', 'prefer-dark') else 'light'


def style():
    """'light' or 'dark': what this person's backgrounds show now ('' before the feature is out on their channel)."""
    if not released('lightdark'):
        return ''
    ld = setting('LightDark')
    return 'light' if ld == 'Light' else 'dark' if ld == 'Dark' else system_style()


def picture_files(bg):
    """(the picture for the light style, for the dark style, and the one showing now). "Always light" or "Always
    dark" uses that one for both."""
    if not released('lightdark') or is_own(bg):
        p = background_path(bg)
        return p, p, p
    ld = setting('LightDark')
    light, dark = background_path(bg, 'light'), background_path(bg, 'dark')
    if ld == 'Light':
        dark = light
    elif ld == 'Dark':
        light = dark
    return light, dark, (dark if system_style() == 'dark' else light)


def gsettings(*args):
    try:
        return subprocess.run(['gsettings'] + list(args), capture_output=True, text=True, timeout=10).stdout.strip()
    except Exception:
        return ''


def background_locked():
    """True when the system (dconf locks, set by another policy) doesn't let people change the desktop picture."""
    return gsettings('writable', 'org.gnome.desktop.background', 'picture-uri') == 'false'


def today():
    """Today's date (TLA_TODAY=YYYY-MM-DD overrides it, for testing the seasons)."""
    try:
        return datetime.date.fromisoformat(os.environ['TLA_TODAY'])
    except (KeyError, ValueError):
        return datetime.date.today()


def easter_sunday(year):
    """Western (Gregorian) Easter Sunday: the Anonymous Gregorian algorithm."""
    a, b, c = year % 19, year // 100, year % 100
    d, e = b // 4, b % 4
    g = (8 * b + 13) // 25
    h = (19 * a + b - d - g + 15) % 30
    i, k = c // 4, c % 4
    l = (32 + 2 * e + 2 * i - h - k) % 7
    m = (a + 11 * h + 19 * l) // 433
    month = (h + l - 7 * m + 90) // 25
    return datetime.date(year, month, (h + l - 7 * m + 33 * month + 19) % 32)


def season(day=None):
    """The seasonal theme in effect: Fall Sep 22 - Nov 30, Christmas Dec 1 - Jan 6, Easter from two weeks before
    Easter Sunday to Easter Monday. None the rest of the year."""
    d = day or today()
    if (d.month == 9 and d.day >= 22) or d.month in (10, 11):
        return 'fall'
    if d.month == 12 or (d.month == 1 and d.day <= 6):
        return 'christmas'
    e = easter_sunday(d.year)
    if e - datetime.timedelta(days=14) <= d <= e + datetime.timedelta(days=1):
        return 'easter'
    if (d.month == 1 and d.day >= 7) or d.month == 2 or (d.month == 3 and d.day <= 19):
        return 'winter'   # (6.4.5)
    return None


def on_default_background():
    """True for someone who hasn't picked a background themselves (or can't: the organization decides)."""
    if signed_out():
        return False                      # (5.7.0: TLA Classic, not the seasonal theme)
    v = mine().get('Background')
    return not users_can_change() or not (valid('Background', v) and released(v))


def surprise_background():
    """A different background each day (never the same two days running), the same all day."""
    st, day = state(), today().isoformat()
    if st.get('SurpriseDay') == day and st.get('SurpriseBackground') in dict(BACKGROUNDS):
        return st['SurpriseBackground']
    import random
    pick = random.choice([b for b, _ in BACKGROUNDS if b != st.get('SurpriseBackground') and released(b)])
    set_state(SurpriseDay=day, SurpriseBackground=pick)
    return pick


def temp_background():
    """A background picked "just for today" or "for one week" (4.2), while that lasts ('' otherwise)."""
    if not users_can_change() or signed_out():
        return ''
    m = mine()
    bg, until = m.get('TempBackground'), m.get('TempUntil')
    if not valid('TempBackground', bg) or not valid('TempUntil', until) or until < today().isoformat() or not released(bg):
        return ''
    return bg


def current_background():
    """The background to show today: one picked for a while (4.2), the seasonal theme for people on the default, a
    daily pick for "Surprise me", otherwise the one chosen."""
    t = temp_background()
    if t:
        return t
    s = season()
    if s and on_default_background() and os.path.exists(background_path(s)):
        return s
    bg = setting('Background')
    return surprise_background() if bg == SURPRISE else bg


def background_needed():
    # (5.0: the light and dark style's pictures, and the lock screen the one for the style showing now)
    light, dark, now = picture_files(current_background())
    for schema, key, want in (('org.gnome.desktop.background', 'picture-uri', light),
                              ('org.gnome.desktop.background', 'picture-uri-dark', dark),
                              ('org.gnome.desktop.screensaver', 'picture-uri', now)):
        if gsettings('get', schema, key).strip("'") != 'file://' + want:
            return True
    return gsettings('get', 'org.gnome.desktop.background', 'picture-options').strip("'") != fit_option()


def fit_option():
    """GNOME's picture-options for how they want the picture to fit the screen (4.2)."""
    return {f: o for f, _, o in FITS}[setting('WallpaperFit')]


def apply_background(if_needed=False):
    if background_locked():
        log('The desktop picture is locked by another policy; not changing it.')
        return False
    bg = current_background()
    path = background_path(bg)
    if not os.path.exists(path):
        log('Background file missing: ' + path)
        return False
    if if_needed and not background_needed():
        return True
    # Desktop (light and dark style) and the lock screen. "zoom" fills the screen; the pictures have spare room
    # above and below, so the logo is the same size as in the intro video. 4.2: or as they chose ("scaled" shows
    # the whole picture, "spanned" stretches it across all screens). 5.0: the light style's picture and the dark
    # style's own, so GNOME switches with the style; the lock screen gets the one for the style showing now (the
    # guard keeps it in step).
    light, dark, now = picture_files(bg)
    fit = fit_option()
    gsettings('set', 'org.gnome.desktop.background', 'picture-uri', 'file://' + light)
    gsettings('set', 'org.gnome.desktop.background', 'picture-uri-dark', 'file://' + dark)
    gsettings('set', 'org.gnome.desktop.background', 'picture-options', fit)
    gsettings('set', 'org.gnome.desktop.screensaver', 'picture-uri', 'file://' + now)
    gsettings('set', 'org.gnome.desktop.screensaver', 'picture-options', fit)
    set_state(AppliedBackground=bg)
    log('Desktop and lock screen set to %s (%s%s).' % (bg, fit, ', light and dark' if light != dark else ''))
    return True


# ---- intro video ------------------------------------------------------------------------------------------------
def video_path(vid):
    return os.path.join(VIDEO_DIR, vid + '.mp4')


def styled_video_path(vid):
    """A video's file in this person's light or dark style (5.0; 5.1.5: also for the play buttons and the unboxing):
    the version for that style where there is one and it's downloaded, otherwise the usual one."""
    st = style()
    # (5.4: and out on their channel: Anime's dark one starts on Experimental)
    if st and VARIANTS.get(vid) == st and os.path.exists(video_path('%s-%s' % (vid, st))) and released('%s-%s' % (vid, st)):
        return video_path('%s-%s' % (vid, st))
    return video_path(vid)


def surprise_video(pick):
    """For "Surprise me": a different video each time it plays (never the same twice running)."""
    last = state().get('SurpriseVideo')
    if not pick:
        return last if last in VIDEO_HASHES else 'tla'
    import random
    have = [v for v, _ in VIDEOS if v in VIDEO_HASHES and os.path.exists(video_path(v)) and released(v)]
    choices = [v for v in have if v != last] or have or ['tla']
    v = random.choice(choices)
    set_state(SurpriseVideo=v)
    return v


def match_video():
    """What "Match my background" plays: the background's own video. A seasonal theme plays its own (4.1), or the
    default background's until that's downloaded."""
    v = current_background()
    if v in dict(SEASONAL) and not os.path.exists(video_path(v)):
        v = org('Background')
    return v


def video_file(pick=False):
    """The intro video to play. pick=True when it's about to play (Surprise me picks a new one then)."""
    v = setting('Video')
    if v == SURPRISE:
        v = surprise_video(pick)
    elif v == 'match':
        v = match_video()
    # 5.0: in the dark style, the dark version of the video where there is one (and it's downloaded).
    if os.path.exists(video_path(v)):
        return styled_video_path(v)
    return styled_video_path('tla')   # a background with no video of its own (yet)


def do_not_disturb():
    return gsettings('get', 'org.gnome.desktop.notifications', 'show-banners') == 'false'


def quiet_now(now=None):
    """Quiet hours (4.0): mute the intro video while Do Not Disturb is on, or during the hours (and days) set."""
    mode = setting('QuietMode')
    if mode == 'DoNotDisturb':
        return do_not_disturb()
    if mode != 'Hours':
        return False
    now = now or datetime.datetime.now()
    start, end = (int(t[:2]) * 60 + int(t[3:]) for t in (setting('QuietStart'), setting('QuietEnd')))
    minute = now.hour * 60 + now.minute
    days = setting('QuietDays').split(',')
    if start <= end:
        return DAYS[now.weekday()] in days and start <= minute < end
    # Overnight (e.g. 21:00 - 07:00): the evening part counts for that day, the morning part for the day before.
    if minute >= start:
        return DAYS[now.weekday()] in days
    return minute < end and DAYS[(now.weekday() - 1) % 7] in days


def greeting(now=None):
    """'Good morning, Audrey!' over the start of the video, when the person has given their name (5.6.0: and hasn't
    turned the greeting off; their name stays either way)."""
    if released('greeting-switch') and setting('Greeting') == 0:
        return ''
    name = ' '.join(str(setting('PreferredName')).split())
    if not name:
        return ''
    h = (now or datetime.datetime.now()).hour
    return 'Good %s, %s!' % ('morning' if h < 12 else 'afternoon' if h < 17 else 'evening', name)


def greeting_style(video):
    """5.6.0: the greeting style for a video file (Videos/<id>[-dark|-light].mp4; other versions share its style)."""
    if not released('greeting-styles'):
        return ''
    vid = re.sub(r'-(v2|original)$', '', re.sub(r'-(dark|light)$', '', os.path.splitext(os.path.basename(video))[0]))
    return GREETING_STYLES.get(vid, '')


def video_key():
    try:
        st = os.stat(video_file())
        return '%d-%d' % (st.st_size, int(st.st_mtime))
    except OSError:
        return ''


def play_video(force=False, vid=None, mute_it=False, unbox=False):
    """4.2: with force, vid plays that video (the play button on a background's picture in the app), and mute_it
    plays without sound ("Play without sound"). 5.0: unbox = the first login after preparing the computer for
    unboxing (vid: TLA Classic, whatever they'd picked)."""
    video = video_file(pick=not vid)
    if (force or unbox) and vid and vid in VIDEO_HASHES and os.path.exists(video_path(vid)):
        video = styled_video_path(vid)    # (5.1.5: in their light or dark style, like the video at login)
    if not os.path.exists(video):
        log('No intro video yet (they download after the install).')
        return False
    skip = force or setting('AllowSkip') == 1
    quiet = setting('Sound') == 1 and quiet_now()
    mute = setting('Sound') != 1 or quiet or (force and mute_it)
    greet = greeting()
    how = '%s, skip %d%s%s' % ('now' if force else 'login', int(skip), ', quiet hours' if quiet else '',
                               ', with greeting' if greet else '')
    if not force:
        set_state(LastPlayed=time.strftime('%Y-%m-%d %H:%M'), LastPlayedDay=time.strftime('%Y-%m-%d'),
                  LastPlayedVideo=video_key())
    if not shutil.which('mpv'):
        # Installed without an administrator, mpv may be missing: GStreamer (part of Ubuntu's desktop) plays it.
        log('Playing %s with GStreamer (%s).' % (os.path.basename(video), how))
        try:
            subprocess.run([sys.executable, os.path.abspath(__file__), 'gst-play', video, str(int(skip)),
                            str(int(mute)), greet], timeout=190)
        except Exception as e:
            log('Could not play the video: %s' % e)
            return False
        return True
    conf = os.path.join(APP_DIR, 'mpv-skip.conf' if skip else 'mpv-noskip.conf')
    cmd = ['mpv', '--fs', '--ontop', '--no-border', '--no-osc', '--osd-level=0', '--no-input-default-bindings',
           '--input-conf=' + conf, '--keep-open=no', '--really-quiet', '--force-window=immediate',
           '--background=color', '--background-color=#000000', '--no-terminal', '--title=TLA BootPaper',
           '--cursor-autohide=always', '--mute=' + ('yes' if mute else 'no')]
    env = None
    lua = os.path.join(APP_DIR, 'greeting.lua')
    if greet and os.path.exists(lua):
        # 5.6.0: in the style of the video's theme, drawn by greeting.lua (TLA Classic's: the classic fade).
        env = dict(os.environ, TLA_GREETING=greet, TLA_GREETING_STYLE=greeting_style(video) or GREETING_STYLES['tla'])
        cmd += ['--script=' + lua]
    elif greet:
        # Shown for the first 4.5 seconds, low in the picture so it doesn't cover the logo. ("$" is special in
        # mpv's message text, so it's doubled.)
        cmd += ['--osd-level=1', '--osd-playing-msg=' + greet.replace('$', '$$'), '--osd-duration=4500',
                '--osd-font-size=58', '--osd-bold=yes', '--osd-align-x=center', '--osd-align-y=bottom',
                '--osd-margin-y=60', '--osd-border-size=2.5', '--osd-shadow-offset=1.5']
    cmd.append(video)
    log('Playing %s (%s).' % (os.path.basename(video), how))
    try:
        subprocess.run(cmd, timeout=180, env=env)
    except Exception as e:
        log('Could not play the video: %s' % e)
        return False
    return True


def os_build():
    try:
        return platform.freedesktop_os_release().get('VERSION_ID', '') + ' ' + platform.release()
    except Exception:
        return platform.release()


def login():
    if os.geteuid() == 0:
        return
    # Once per login session (the autostart entry can run twice if the session restarts).
    session = os.environ.get('XDG_SESSION_ID', '0')
    marker = os.path.join('/run/user', str(os.getuid()), 'tla-bootpaper-' + session)
    try:
        os.close(os.open(marker, os.O_CREAT | os.O_EXCL))
    except FileExistsError:
        return
    except OSError:
        pass
    # Background first (fast), then the video.
    apply_background(if_needed=True)
    if not os.access(APP_DIR, os.W_OK):
        pass                              # installed for everyone: the root guard downloads the videos
    else:
        # Installed for this person: make sure their guard timer is running (the install may not have been
        # able to reach systemd), and that the videos are coming down.
        unit = os.path.join(os.environ.get('XDG_CONFIG_HOME') or os.path.expanduser('~/.config'),
                            'systemd', 'user', 'tla-bootpaper-guard.timer')
        if os.path.exists(unit):
            try:
                subprocess.run(['systemctl', '--user', 'daemon-reload'], capture_output=True, timeout=20)
                subprocess.run(['systemctl', '--user', 'enable', '--now', 'tla-bootpaper-guard.timer'],
                               capture_output=True, timeout=20)
            except Exception:
                pass
    if os.access(APP_DIR, os.W_OK) and not os.path.exists(os.path.join(APP_DIR, '.videos-ok')):
        subprocess.Popen([sys.executable, os.path.abspath(__file__), 'guard'], stdout=subprocess.DEVNULL,
                         stderr=subprocess.DEVNULL, start_new_session=True)
    build = os_build()
    st = state()
    # Unboxing (5.0): prepared, started up since, and this person hasn't had it yet: TLA Classic (whatever the
    # settings), then the Welcome to TLA tour.
    unbox_at = unbox_pending()
    if unbox_at:
        log('Unboxing: TLA Classic, then the Welcome to TLA tour.')
        set_state(UnboxShown=unbox_at, SeenRelease=shown_release(), LastSeenBuild=build)
        play_video(vid='tla', unbox=True)
        run_app(tour_only=True)
        start_nudge()
        return
    play = setting('Enabled') == 1
    when = setting('PlayWhen')
    if when == 'OncePerDay' and st.get('LastPlayedDay') == time.strftime('%Y-%m-%d'):
        play = False
    elif when == 'AfterUpdate' and (not st.get('LastSeenBuild') or st.get('LastSeenBuild') == build):
        play = False
    elif when == 'FirstTime' and st.get('LastPlayedVideo') == video_key():
        play = False
    if play:
        play_video()
    set_state(LastSeenBuild=build)
    text = announcement()
    if text:
        notify('Announcement', text)
    # Once (4.0): ask what name to greet them by. They can skip it, and change it later in the app. 4.0.5: only
    # "Save" or "Not now" count as answered; closed any other way, it's asked again next login (at most 3 times).
    if users_can_change() and not signed_out() and setting('Enabled') == 1 and not state().get('NameAsked'):
        tries = int(state().get('NameTries') or 0) + 1
        set_state(NameTries=tries, **({'NameAsked': 1} if tries >= 3 else {}))
        run_app(ask_name_only=True)
    if state().get('SeenRelease') != shown_release():     # (4.3: their channel's release)
        set_state(SeenRelease=shown_release())
        run_app(whats_new_only=True)
    start_nudge()
    if signin_now()['state'] != 'off':        # (5.7.0: "sign in again" reminders, in their own process)
        subprocess.Popen([sys.executable, os.path.abspath(__file__), 'signin-remind'], stdout=subprocess.DEVNULL,
                         stderr=subprocess.DEVNULL, start_new_session=True)


def start_nudge():
    """A TLA Care reminder (5.0), a few minutes after login: in its own process, so login finishes now."""
    if released('care') and setting('CareReminders') == 1:
        subprocess.Popen([sys.executable, os.path.abspath(__file__), 'nudge'], stdout=subprocess.DEVNULL,
                         stderr=subprocess.DEVNULL, start_new_session=True)


def nudge(wait=180):
    """Three minutes after login: a notification for what's worth doing something about (at most once a day), with
    an "Open TLA Care" button where the notification system has buttons."""
    time.sleep(wait)
    pick = care_nudge()
    if not pick:
        return
    set_state(CareNudgeDay=today().isoformat(), CareNudgeFor='%s|%s' % (pick['id'], pick['status']))
    icon = os.path.join(APP_DIR, 'AppIcon.png')
    clicked = ''
    try:
        r = subprocess.run(['notify-send', '--app-name=TLA Care', '--icon=' + icon, '--action=open=Open TLA Care',
                            '--wait', '--expire-time=60000', pick['title'], pick['detail']],
                           capture_output=True, text=True, timeout=120)
        if r.returncode != 0:
            raise OSError(r.stderr.strip())
        clicked = r.stdout.strip()
    except Exception:
        notify('TLA Care: ' + pick['title'], pick['detail'] + ' Open TLA Care from Activities to fix it.')
    if clicked == 'open':
        subprocess.Popen([sys.executable, os.path.abspath(__file__), 'care'], start_new_session=True)


# ---- announcements ----------------------------------------------------------------------------------------------
def clean_announcement(text):
    """The announcement text: comment lines (starting with #) and blank lines dropped, at most 300 characters."""
    lines = [l.strip() for l in text.splitlines() if l.strip() and not l.strip().startswith('#')]
    text = ' '.join(lines)
    return ''.join(c for c in text if c.isprintable())[:300].strip()


def announcement():
    try:
        return clean_announcement(open(ANNOUNCEMENT_FILE, encoding='utf-8').read())
    except OSError:
        return ''


def notify(title, body):
    """A desktop notification from TLA BootPaper (it also shows on the lock screen's notification list)."""
    icon = os.path.join(APP_DIR, 'AppIcon.png')
    try:
        if shutil.which('notify-send'):
            subprocess.run(['notify-send', '--app-name=TLA BootPaper', '--icon=' + icon, title, body], timeout=10)
        else:
            subprocess.run(['gdbus', 'call', '--session', '--dest', 'org.freedesktop.Notifications',
                            '--object-path', '/org/freedesktop/Notifications', '--method',
                            'org.freedesktop.Notifications.Notify', gvariant_string('TLA BootPaper'), '0',
                            gvariant_string(icon), gvariant_string(title), gvariant_string(body), '[]', '{}',
                            '-1'], capture_output=True, timeout=10)
    except Exception as e:
        log('Could not show a notification: %s' % e)


def gvariant_string(text):
    return "'" + text.replace('\\', '\\\\').replace("'", "\\'") + "'"


def set_login_banner(text):
    """Shows the announcement on the login screen (GDM's banner message), or removes it. Ubuntu 24.04 builds the
    login screen's settings from /usr/share/gdm/dconf when GDM starts (generate-config); older releases use the
    gdm dconf database."""
    if os.path.exists('/usr/share/gdm/generate-config'):
        path, rebuild = '/usr/share/gdm/dconf/95-tla-announcement', ['/usr/share/gdm/generate-config']
    else:
        path, rebuild = '/etc/dconf/db/gdm.d/95-tla-announcement', ['dconf', 'update']
    try:
        if text:
            os.makedirs(os.path.dirname(path), exist_ok=True)
            with open(path, 'w', encoding='utf-8') as f:
                f.write('# TLA BootPaper: the announcement on the login screen (from GitHub)\n'
                        '[org/gnome/login-screen]\nbanner-message-enable=true\nbanner-message-text=%s\n'
                        % gvariant_string(text))
        elif os.path.exists(path):
            os.remove(path)
        else:
            return
        subprocess.run(rebuild, capture_output=True, timeout=60)
    except Exception as e:
        log('Could not update the login screen announcement: %s' % e)


def sync_announcement():
    """Root, every 15 minutes: fetch the announcement from GitHub; when it changes, save it and update the login
    screen. Offline, the last one stays."""
    try:
        raw = urllib.request.urlopen(ANNOUNCEMENT_URL, timeout=30).read().decode('utf-8', 'replace')
    except Exception as e:
        if '404' in str(e):
            raw = ''        # no announcement file: no announcement
        else:
            return
    text = clean_announcement(raw)
    if text == announcement() and os.path.exists(ANNOUNCEMENT_FILE):
        return
    os.makedirs(os.path.dirname(ANNOUNCEMENT_FILE), exist_ok=True)
    with open(ANNOUNCEMENT_FILE + '.tmp', 'w', encoding='utf-8') as f:
        f.write(text + '\n' if text else '')
    os.chmod(ANNOUNCEMENT_FILE + '.tmp', 0o644)
    os.replace(ANNOUNCEMENT_FILE + '.tmp', ANNOUNCEMENT_FILE)
    set_login_banner(text)
    log('Announcement %s.' % ('set: ' + text if text else 'cleared'))


# ---- helpdesk ---------------------------------------------------------------------------------------------------
def helpdesk_link():
    """mailto: for the helpdesk, with this computer's details filled in (4.0), so reports say where they're from."""
    from urllib.parse import quote
    body = ('\n\n\n'
            '-- Please keep these details: they help the helpdesk --\n'
            'Computer: %s\nSystem: Ubuntu %s\nTLA BootPaper: %s\nBackground: %s\nIntro video: %s\n'
            % (platform.node(), os_build(), version_summary(), bg_name(current_background()),
               dict(VIDEOS).get(setting('Video'), setting('Video'))))
    return 'mailto:%s?subject=%s&body=%s' % (HELPDESK, quote('TLA BootPaper (Linux)'), quote(body))


# ---- Report a problem (4.3) -------------------------------------------------------------------------------------
REPORT_TOPICS = ['Sound, speakers or microphone', 'Screen or display', 'Keyboard, mouse or touchpad', 'Wi-Fi or internet',
                 'Battery or charging', 'Camera', 'Signing in or passwords', 'An app or website',
                 'Slow, freezing or crashing', 'Printing', 'TLA BootPaper (backgrounds or intro videos)', 'Something else']
DEVICE_INFO = os.path.join(APP_DIR, 'device-info.json')


def read_text(path):
    try:
        with open(path) as f:
            return f.read().strip()
    except OSError:
        return ''


def save_device_info():
    """Root (the guard): the computer's maker, model and serial number, which only root can read, kept where the
    report form can read them."""
    info = {k: read_text('/sys/class/dmi/id/' + f) for k, f in
            (('vendor', 'sys_vendor'), ('product', 'product_name'), ('serial', 'product_serial'))}
    info = {k: v for k, v in info.items() if v}
    if info and read_json(DEVICE_INFO) != info:
        write_json(DEVICE_INFO, info)
        os.chmod(DEVICE_INFO, 0o644)


def ago(seconds):
    if seconds < 120:
        return 'just now'
    if seconds < 7200:
        return '%d minutes ago' % (seconds // 60)
    if seconds < 172800:
        return '%d hours ago' % (seconds // 3600)
    return '%d days ago' % (seconds // 86400)


def device_details():
    """What the helpdesk needs to find this computer and see what state it's in: [(label, value)]. Anything that
    can't be read is left out."""
    d = [('Computer', platform.node())]
    info = read_json(DEVICE_INFO)
    vendor = info.get('vendor') or read_text('/sys/class/dmi/id/sys_vendor')
    product = info.get('product') or read_text('/sys/class/dmi/id/product_name')
    if vendor or product:
        d.append(('Model', ' '.join(x for x in (vendor, product) if x)))
    serial = info.get('serial') or read_text('/sys/class/dmi/id/product_serial')
    if serial:
        d.append(('Serial number', serial))
    try:
        cpu = next(l.split(':', 1)[1].strip() for l in open('/proc/cpuinfo') if l.startswith('model name'))
        d.append(('Processor', ' '.join(cpu.split())))
    except Exception:
        pass
    try:
        kb = next(int(l.split()[1]) for l in open('/proc/meminfo') if l.startswith('MemTotal:'))
        d.append(('Memory', '%d GB' % round(kb / 1024 / 1024)))
    except Exception:
        pass
    d.append(('System', 'Ubuntu ' + os_build()))
    try:
        up = float(open('/proc/uptime').read().split()[0])
        boot = datetime.datetime.now() - datetime.timedelta(seconds=up)
        d.append(('Last restart', '%s (%s)' % (boot.strftime('%a %b %-d, %-I:%M %p'), ago(up))))
    except Exception:
        pass
    d.append(('Restart needed', 'Yes (updates are waiting for a restart)' if os.path.exists('/var/run/reboot-required') else 'No'))
    try:
        u = shutil.disk_usage('/')
        d.append(('Storage', '%d GB free of %d GB' % (u.free / 1e9, u.total / 1e9)))
    except Exception:
        pass
    import glob
    for bat in sorted(glob.glob('/sys/class/power_supply/BAT*'))[:1]:
        cap, status = read_text(bat + '/capacity'), read_text(bat + '/status')
        text = '%s%%, %s' % (cap, 'on battery' if status == 'Discharging' else 'plugged in') if cap else ''
        for full, design in (('energy_full', 'energy_full_design'), ('charge_full', 'charge_full_design')):
            f, g = read_text('%s/%s' % (bat, full)), read_text('%s/%s' % (bat, design))
            if f.isdigit() and g.isdigit() and int(g):
                text += '; health %d%% of new' % min(100, round(100 * int(f) / int(g)))
                break
        if text:
            d.append(('Battery', text))
    try:
        out = subprocess.run(['nmcli', '-t', '-f', 'TYPE,STATE,CONNECTION', 'device'], capture_output=True, text=True,
                             timeout=5).stdout.splitlines()
        wifi = [l.split(':', 2) for l in out if l.startswith('wifi:')]
        if wifi:
            w = wifi[0]
            d.append(('Wi-Fi', w[2] if len(w) > 2 and w[1] == 'connected' and w[2] else 'not connected'))
    except Exception:
        pass
    d.append(('TLA BootPaper', version_summary()))
    si = signin_now()
    if si['state'] != 'off':          # (5.7.0)
        d.append(('Signed in', {'in': 'Yes', 'renew': 'Yes, until %s' % signin_when(si.get('until', 0)),
                                'grace': 'Ran out (offline: %d more days)' % si.get('days', 0)}.get(
                                    si['state'], 'No') + (' as %s' % si['who'] if si.get('who') else '')))
    d.append(('Background', bg_name(current_background())))
    d.append(('Intro video', dict(VIDEOS).get(setting('Video'), setting('Video'))))
    d.append(('Reported', datetime.datetime.now().strftime('%A, %B %-d, %Y %-I:%M %p')))
    return d


def report_email(topic, urgent, text, details):
    """(subject, body) of the email to the helpdesk."""
    subject = '%sProblem report: %s (%s)' % ('URGENT - ' if urgent else '', topic, platform.node())
    body = ("What it's about: %s\nHow much it's getting in the way: %s\n\nWhat happened:\n%s\n\n"
            '-- Details about this computer (added by TLA BootPaper) --\n%s\n'
            % (topic, "I can't do my work" if urgent else 'I can still work around it', text.strip(), details))
    return subject, body


# ---- release log ------------------------------------------------------------------------------------------------
def release_notes(limit=0):
    """The shared release log, without the Windows-only and Mac-only lines. Returns [(title, [lines])]. 4.3: each
    release is marked (Stable) or (Experimental), and releases newer than this person's channel are left out."""
    sections, cur = [], None
    try:
        lines = open(os.path.join(APP_DIR, 'release-notes.md'), encoding='utf-8').read().splitlines()
    except Exception:
        return []
    for line in lines:
        if line.startswith('# '):
            title = line[2:].strip()
            if title.startswith('[win]') or title.startswith('[mac]'):
                cur = None
                continue
            title = title.replace('[linux]', '').strip()
            # Linux starts at 3.4: older history is about the Windows and Mac versions.
            try:
                ver = tuple(int(x) for x in title.split()[-1].split('.'))
                if ver < (3, 4):
                    break
            except ValueError:
                pass
            v = title.split()[-1]
            if vkey(v):
                if vkey(v) > vkey(channel_release()):
                    cur = None
                    continue
                title = '%s (%s)' % (title, release_label(v))
            cur = (title, [])
            sections.append(cur)
        elif cur is not None and line.startswith('- '):
            item = line[2:].strip()
            if item.startswith('[win]') or item.startswith('[mac]'):
                continue
            cur[1].append(item.replace('[linux]', '').strip())
    sections = [s for s in sections if s[1]]
    return sections[:limit] if limit else sections


# ---- root: keep backgrounds, download videos --------------------------------------------------------------------
# ---- TLA Care (5.0) ---------------------------------------------------------------------------------------------
# Checks what most often goes wrong on a school computer and fixes what it can with one click. What needs root
# (clearing out system leftovers, downloading the videos now, preparing for unboxing) is asked of the guard, which
# runs as root every 20 seconds when TLA BootPaper is installed for everyone: the person's state.json holds one word
# from a fixed list (CareRequest), so nothing else can be asked for, and the answer comes back in Care/result
# ("<word>|<time asked>|<text>"). Sound is the person's own (PipeWire runs in their session), so that's fixed directly.
CARE_DIR = os.path.join(APP_DIR, 'Care')
CARE_RESULT = os.path.join(CARE_DIR, 'result')
CARE_REQUESTS = ('cleanup', 'videos', 'unbox', 'signin', 'update')   # (5.7.0: signin; 5.8.0: update)
UNBOX_FILE = '/etc/tla-bootpaper/unbox.json'
CONNECTIVITY_URL = 'http://connectivity-check.ubuntu.com/'


def installed_for_everyone():
    return APP_DIR == '/opt/tla-bootpaper' or APP_DIR.startswith('/opt/')


def boot_time():
    try:
        for line in open('/proc/stat'):
            if line.startswith('btime '):
                return int(line.split()[1])
    except (OSError, ValueError):
        pass
    return 0


def care_row(cid, status, title, detail, action='', action_text=''):
    return {'id': cid, 'status': status, 'title': title, 'detail': detail, 'action': action, 'action_text': action_text}


def pipewire_running():
    try:
        return subprocess.run(['pgrep', '-u', str(os.getuid()), '-x', 'pipewire'], capture_output=True,
                              timeout=5).returncode == 0
    except Exception:
        return True       # (can't tell: don't claim it's broken)


def fingerprint_state():
    """'set' (this person has a fingerprint added), 'reader' (the computer has a reader, but they haven't), or ''
    (no reader, or fprintd isn't installed)."""
    if not shutil.which('fprintd-list'):
        return ''
    try:
        out = subprocess.run(['fprintd-list', pwd.getpwuid(os.getuid()).pw_name], capture_output=True, text=True,
                             timeout=5).stdout
    except Exception:
        return ''
    # ("found 1 devices ... - #0: right-index-finger", or "... has no fingers enrolled", or "No devices available")
    if not out.strip() or 'no devices' in out.lower():
        return ''
    return 'set' if re.search(r'#\d+:', out) else 'reader'


def open_settings(*panels):
    """Opens GNOME Settings at the first of these pages this version has (their names change between versions)."""
    if not shutil.which('gnome-control-center'):
        return False
    have = [p for p in panels if os.path.exists('/usr/share/applications/gnome-%s-panel.desktop' % p)]
    try:
        subprocess.Popen(['gnome-control-center'] + have[:1], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                         start_new_session=True)
        return True
    except OSError:
        return False


def care_checks(quick=False):
    """Each check: a care_row with status ok | info | warn | bad. quick: only what's worth a reminder (restart,
    storage, sound), with no network test."""
    import glob
    rows = []
    boot = boot_time()
    if boot:
        up = time.time() - boot
        days = int(up // 86400)
        pending = os.path.exists('/var/run/reboot-required')
        if days >= 14:
            rows.append(care_row('restart', 'bad', 'Restart your computer', "It hasn't restarted in %d days. A restart "
                                 'keeps it fast and finishes updates.' % days, 'restart', 'Restart now'))
        elif pending and days >= 1:
            rows.append(care_row('restart', 'warn', 'Updates are waiting for a restart',
                                 'Restart to finish installing them. Last restart: %s.' % ago(up), 'restart', 'Restart now'))
        elif days >= 7:
            rows.append(care_row('restart', 'warn', 'Time for a restart', "It's been running for %d days. A restart keeps "
                                 'it fast.' % days, 'restart', 'Restart now'))
        else:
            rows.append(care_row('restart', 'ok', 'Restart', 'Restarted %s.%s' % (
                ago(up), ' Updates will finish at the next restart.' if pending else '')))
    try:
        u = shutil.disk_usage('/')
        free, total = u.free / 1e9, u.total / 1e9
        pct = 100 * u.free / u.total
        text = '%.1f GB free of %.0f GB.' % (free, total)
        if pct < 5 or free < 5:
            rows.append(care_row('storage', 'bad', 'Almost out of storage', text + ' Apps and updates need room to work.',
                                 'cleanup', 'Free up space'))
        elif pct < 10 or free < 15:
            rows.append(care_row('storage', 'warn', 'Storage is getting full', text, 'cleanup', 'Free up space'))
        else:
            rows.append(care_row('storage', 'ok', 'Storage', text))
    except Exception:
        pass
    if not quick:
        try:
            ok = urllib.request.urlopen(CONNECTIVITY_URL, timeout=4).status in (200, 204)
        except Exception:
            ok = False
        if ok:
            rows.append(care_row('internet', 'ok', 'Internet', 'Connected.'))
        else:
            rows.append(care_row('internet', 'bad', "Can't reach the internet", 'Check that Wi-Fi is on and pick your '
                                 'network. If a sign-in page should appear, open a browser.', 'wifi', 'Wi-Fi settings'))
    if pipewire_running():
        rows.append(care_row('sound', 'ok', 'Sound', 'Working. No sound or no microphone? Reset it.', 'audio', 'Reset sound'))
    else:
        rows.append(care_row('sound', 'bad', "Sound isn't working", 'The sound system has stopped.', 'audio', 'Fix sound'))
    if not quick:
        for bat in sorted(glob.glob('/sys/class/power_supply/BAT*'))[:1]:
            cap = read_text(bat + '/capacity')
            health = None
            for full, design in (('energy_full', 'energy_full_design'), ('charge_full', 'charge_full_design')):
                f, g = read_text('%s/%s' % (bat, full)), read_text('%s/%s' % (bat, design))
                if f.isdigit() and g.isdigit() and int(g):
                    health = min(100, round(100 * int(f) / int(g)))
                    break
            if health is not None and health < 50:
                rows.append(care_row('battery', 'warn', 'The battery is wearing out', "It holds about %d%% of its charge "
                                     "when new. If it doesn't last the school day, tell the helpdesk." % health,
                                     'report', 'Report it'))
            elif cap:
                rows.append(care_row('battery', 'ok', 'Battery', '%s%% charged%s.' % (
                    cap, '; battery health %d%%' % health if health is not None else '')))
        # Fingerprint sign-in, where the computer has a reader.
        fp = fingerprint_state()
        if fp == 'set':
            rows.append(care_row('fingerprint', 'ok', 'Fingerprint sign-in', "You're set up."))
        elif fp == 'reader':
            rows.append(care_row('fingerprint', 'info', 'Sign in with your fingerprint', "This computer can do it, and "
                                 "it's faster than typing your password.", 'fingerprint', 'Set it up'))
    missing = [v for v in VIDEO_HASHES if not os.path.exists(video_path(v))]
    if missing:
        rows.append(care_row('bootpaper', 'info', 'TLA BootPaper', '%d intro video%s still downloading.' % (
            len(missing), '' if len(missing) == 1 else 's'), 'videos', 'Download now'))
    else:
        rows.append(care_row('bootpaper', 'ok', 'TLA BootPaper', 'Backgrounds and intro videos are all in place.'))
    return rows


def care_request(action):
    """Asks the guard (root) to do one thing from the list. Returns the time asked (to match its answer), or None."""
    if action not in CARE_REQUESTS or not installed_for_everyone():
        return None
    at = str(int(time.time()))
    set_state(CareRequest=action, CareRequestAt=at)
    return at


def care_result(action, at):
    """The guard's answer to a request (its text), once it has answered."""
    r = read_text(CARE_RESULT)
    prefix = '%s|%s|' % (action, at)
    return r[len(prefix):] if r.startswith(prefix) else None


def clear_my_cache(cache=None):
    """The person's own cached files that haven't been used for two weeks (~/.cache): apps make them again when they
    need them. Returns the bytes freed."""
    cache = cache or os.path.join(os.environ.get('XDG_CACHE_HOME') or os.path.expanduser('~/.cache'))
    if os.path.basename(cache.rstrip('/')) != '.cache' and not os.environ.get('TLA_TEST_CACHE'):
        return 0
    cutoff, freed = time.time() - 14 * 86400, 0
    for root, _dirs, files in os.walk(cache):
        for f in files:
            p = os.path.join(root, f)
            try:
                st = os.lstat(p)
                if st.st_mtime < cutoff and st.st_atime < cutoff and not os.path.islink(p):
                    os.remove(p)
                    freed += st.st_size
            except OSError:
                pass
    return freed


def fix_sound():
    """Restarts the person's own sound system (PipeWire), which brings back speakers and microphones."""
    try:
        r = subprocess.run(['systemctl', '--user', 'restart', 'pipewire', 'pipewire-pulse', 'wireplumber'],
                           capture_output=True, text=True, timeout=30)
        ok = r.returncode == 0
    except Exception:
        ok = False
    log('TLA Care: restarted the sound system (%s).' % ('done' if ok else 'failed'))
    return ("Done: the sound system was restarted. If there's still no sound, check the volume, then report the problem."
            if ok else "Couldn't restart the sound system. Restart the computer, or report the problem.")


def care_nudge():
    """The check worth a reminder today, or None: at most one a day, for a restart that's overdue, storage running out
    or sound not working, never the same one two days running unless it got worse, and not if reminders are off."""
    if not released('care') or setting('CareReminders') != 1:
        return None
    st, day = state(), today()
    if st.get('CareNudgeDay') == day.isoformat():
        return None
    rows = [r for r in care_checks(quick=True) if r['id'] in ('restart', 'storage', 'sound') and r['status'] in ('warn', 'bad')]
    if not rows:
        return None
    pick = ([r for r in rows if r['status'] == 'bad'] + rows)[0]
    if (st.get('CareNudgeDay') == (day - datetime.timedelta(days=1)).isoformat()
            and st.get('CareNudgeFor') == '%s|%s' % (pick['id'], pick['status'])):
        return None
    return pick


# ---- Unboxing (5.0) ---------------------------------------------------------------------------------------------
# /etc/tla-bootpaper/unbox.json (root's): state ready (a computer TLA BootPaper was first installed on, until someone
# prepares it) | armed (prepared, shutting down) | unboxing (it has started up since) | done; armed_at = when.
# armed_by "update": a computer that already had TLA BootPaper when 5.0 arrived (install.sh arms it, so the tour
# comes by itself after its next startup, once the tour is out on that person's release channel). Installed for one
# person, it's their own ~/.config/tla-bootpaper/unbox.json (only ever armed by an update).
def unbox_info():
    return read_json(UNBOX_FILE if installed_for_everyone() else os.path.join(config_dir(), 'unbox.json'))


def unbox_pending():
    """armed_at when this login is the unboxing (prepared, started up since, and this person hasn't had it), else None."""
    u = unbox_info()
    at = u.get('armed_at')
    if u.get('state') not in ('armed', 'unboxing') or not isinstance(at, int):
        return None
    if state().get('UnboxShown') == at:
        return None
    if u.get('armed_by') == 'update' and not released('tour'):
        return None
    if u.get('state') == 'armed' and not boot_time() > at:
        return None
    return at


def write_unbox(**kw):
    kw['changed'] = int(time.time())
    write_json(UNBOX_FILE, kw)
    os.chmod(UNBOX_FILE, 0o644)


# ---- TLA call backgrounds (5.0) ---------------------------------------------------------------------------------
def call_pictures_folder():
    """Puts every TLA background out on this person's channel, light and dark, in ~/Pictures/TLA backgrounds (for
    Teams on the web, Zoom and other call apps, which add backgrounds from a picture), and returns the folder."""
    pictures = subprocess.run(['xdg-user-dir', 'PICTURES'], capture_output=True, text=True).stdout.strip() \
        if shutil.which('xdg-user-dir') else ''
    folder = os.path.join(pictures or os.path.expanduser('~/Pictures'), 'TLA backgrounds')
    os.makedirs(folder, exist_ok=True)
    for bg, name in BACKGROUNDS:
        if not released(bg):
            continue
        looks = [(background_path(bg), name)]
        if released('lightdark') and bg in VARIANTS:
            looks.append((background_path(bg, VARIANTS[bg]), '%s (%s)' % (name, VARIANTS[bg])))
        for src, title in looks:
            dst = os.path.join(folder, title + '.jpg')
            try:
                if os.path.exists(src) and (not os.path.exists(dst) or os.path.getsize(dst) != os.path.getsize(src)):
                    shutil.copyfile(src, dst)
            except OSError:
                pass
    return folder


def sha256(path):
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        for chunk in iter(lambda: f.read(1 << 20), b''):
            h.update(chunk)
    return h.hexdigest()


def sync_videos():
    os.makedirs(VIDEO_DIR, exist_ok=True)
    missing = 0
    for vid, want in VIDEO_HASHES.items():
        target = os.path.join(VIDEO_DIR, vid + '.mp4')
        if os.path.exists(target) and sha256(target) == want:
            continue
        tmp = os.path.join(VIDEO_DIR, '.' + vid + '.download')
        try:
            urllib.request.urlretrieve('%s/%s.mp4' % (VIDEO_SOURCE, VIDEO_REMOTE.get(vid, vid)), tmp)
            if sha256(tmp) != want:
                raise ValueError("the file doesn't match")
            os.chmod(tmp, 0o644)
            os.replace(tmp, target)
            log('Downloaded the %s video.' % vid)
        except Exception as e:
            missing += 1
            log("Couldn't get the %s video yet (%s)." % (vid, e))
            try:
                os.remove(tmp)
            except OSError:
                pass
    # A video taken off the list (3.4.4: Solarpunk, being redone) is removed, so nobody keeps playing it.
    for name in os.listdir(VIDEO_DIR):
        vid = name[:-4]
        if name.endswith('.mp4') and vid not in VIDEO_HASHES:
            try:
                os.remove(os.path.join(VIDEO_DIR, name))
                log('Removed the %s video (no longer offered).' % vid)
            except OSError:
                pass
    return missing


def graphical_sessions():
    """(user, uid) for every active graphical login."""
    out = []
    try:
        lines = subprocess.run(['loginctl', 'list-sessions', '--no-legend'], capture_output=True, text=True,
                               timeout=10).stdout.splitlines()
    except Exception:
        return out
    for line in lines:
        f = line.split()
        if len(f) < 3:
            continue
        info = subprocess.run(['loginctl', 'show-session', f[0], '-p', 'Type', '-p', 'Active', '-p', 'Name',
                               '-p', 'User', '-p', 'Class'], capture_output=True, text=True).stdout
        p = dict(x.split('=', 1) for x in info.splitlines() if '=' in x)
        if p.get('Type') in ('wayland', 'x11') and p.get('Class') == 'user' and p.get('Active') == 'yes':
            out.append((p.get('Name'), int(p.get('User', 0))))
    return list(dict.fromkeys(out))


def as_user(user, uid, args, timeout=60):
    env = ['DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/%d/bus' % uid, 'XDG_RUNTIME_DIR=/run/user/%d' % uid,
           'HOME=' + pwd.getpwuid(uid).pw_dir]
    return subprocess.run(['runuser', '-u', user, '--', 'env'] + env + args, capture_output=True, text=True,
                          timeout=timeout)


def self_update(force=False):
    """Updates come from GitHub (3.6): every 6 hours, fetch the Intune Linux script and, if it names a different
    version from the one installed, run it. It downloads the new bundle and only installs it if its SHA-256
    matches. So once installed, TLA BootPaper keeps itself up to date without anyone signing in to the admin
    account (where the Intune agent runs)."""
    stamp = os.path.join(APP_DIR, '.update-checked')
    try:
        age = time.time() - os.path.getmtime(stamp)
    except OSError:
        age = 1e9
    if age < 6 * 3600 and not force:
        return
    try:
        open(stamp, 'w').close()
        script = urllib.request.urlopen(UPDATE_SCRIPT, timeout=30).read().decode('utf-8')
    except Exception as e:
        log("Couldn't check for updates (%s)." % e)
        return
    m = re.search(r'^VERSION="([0-9][0-9.]*)"$', script, re.M)
    if not script.startswith('#!/bin/bash') or not m or 'install.sh' not in script:
        log("Update check: GitHub's script doesn't look right; not running it.")
        return
    try:
        installed = open(os.path.join(APP_DIR, 'VERSION')).read().strip()
    except OSError:
        installed = ''
    if m.group(1) == installed:
        return
    log('Updating TLA BootPaper %s to %s.' % (installed or '?', m.group(1)))
    fd, path = tempfile.mkstemp(suffix='.sh')
    try:
        with os.fdopen(fd, 'w') as f:
            f.write(script)
        r = subprocess.run(['/bin/bash', path], capture_output=True, text=True, timeout=900)
        log('Update: %s' % (r.stdout.strip().splitlines() or ['(no output)'])[-1])
    except Exception as e:
        log('Update failed: %s' % e)
    finally:
        try:
            os.remove(path)
        except OSError:
            pass


def check_update_now():
    """5.8.0: "Check for updates" in the app (the guard, as root, or the person's own copy): GitHub's Linux script now,
    and when it names a different version from this one, self_update() runs it in the background. Returns what to
    tell them."""
    try:
        script = urllib.request.urlopen(UPDATE_SCRIPT, timeout=20).read().decode('utf-8')
        m = re.search(r'^VERSION="([0-9][0-9.]*)"$', script, re.M)
        if not script.startswith('#!/bin/bash') or not m:
            raise ValueError("GitHub's script doesn't look right")
    except Exception as e:
        log("Check for updates: couldn't check (%s)." % e)
        return "Couldn't check for updates. Check that this computer is online, then try again."
    try:
        installed = open(os.path.join(APP_DIR, 'VERSION')).read().strip()
    except OSError:
        installed = ''
    if m.group(1) == installed:
        log('Check for updates: up to date (%s).' % installed)
        return "You're up to date."
    subprocess.Popen([sys.executable, os.path.abspath(__file__), 'update'], stdout=subprocess.DEVNULL,
                     stderr=subprocess.DEVNULL, start_new_session=True)
    log('Check for updates: %s is out; started the update.' % m.group(1))
    return 'Version %s is out (this computer has %s). Installing it now: this takes a few minutes.' % (m.group(1), installed or RELEASE)


def bc_time():
    """7.4.0: British Columbia time, UTC-7 all year (BC stopped changing clocks on March 8, 2026). America/Vancouver
    once this computer's time zone data knows that rule, America/Whitehorse (Yukon, the same clock) until then.
    Runs as root from the guard; does nothing if the zone is already right."""
    def offset_in_january(zone):
        r = subprocess.run(['date', '-d', '%d-01-15 12:00' % (time.localtime().tm_year + 1), '+%z'],
                           env=dict(os.environ, TZ=zone), capture_output=True, text=True)
        return r.stdout.strip()
    zone = 'America/Vancouver' if offset_in_january('America/Vancouver') == '-0700' else 'America/Whitehorse'
    try:
        current = os.path.realpath('/etc/localtime').split('/zoneinfo/')[-1]
    except OSError:
        current = ''
    if current != zone:
        subprocess.run(['timedatectl', 'set-ntp', 'true'], capture_output=True)
        if subprocess.run(['timedatectl', 'set-timezone', zone], capture_output=True).returncode == 0:
            log('Time zone set to %s (BC time, UTC-7 all year; it was %s).' % (zone, current or 'unknown'))


def guard():
    self_update()
    if os.geteuid() == 0:
        try:
            bc_time()   # (7.4.0)
        except Exception as e:
            log('BC time: %s' % e)
        stamp = os.path.join(APP_DIR, '.announcement-checked')
        try:
            age = time.time() - os.path.getmtime(stamp)
        except OSError:
            age = 1e9
        if age > 900:
            open(stamp, 'w').close()
            sync_announcement()
    # Release channels (4.3): every 15 minutes.
    stamp = os.path.join(APP_DIR, '.channels-checked')
    try:
        age = time.time() - os.path.getmtime(stamp)
    except OSError:
        age = 1e9
    if age > 900:
        open(stamp, 'w').close()
        sync_channels()
        if os.geteuid() == 0:
            save_device_info()
    # 5.7.0: the sign-in settings and the keys sign-ins are checked against (every 6 hours).
    try:
        sync_signin()
    except Exception as e:
        log('Sign-in settings: %s' % e)
    # Videos: every 15 minutes until they're all in place (then once a day, to pick up new ones).
    stamp = os.path.join(APP_DIR, '.videos-checked')
    try:
        age = time.time() - os.path.getmtime(stamp)
    except OSError:
        age = 1e9
    ok = os.path.exists(os.path.join(APP_DIR, '.videos-ok'))
    if age > (86400 if ok else 900):
        open(stamp, 'w').close()
        if sync_videos() == 0:
            open(os.path.join(APP_DIR, '.videos-ok'), 'w').close()
        else:
            try:
                os.remove(os.path.join(APP_DIR, '.videos-ok'))
            except OSError:
                pass
    # Backgrounds: whoever is at the screen keeps their preset (put back if changed in Settings). Installed for
    # one person, the guard runs as that person and looks after their own desktop.
    if os.geteuid() != 0:
        apply_background(if_needed=True)
        return
    # 5.0: unboxing, from prepared to started up.
    unbox = unbox_info()
    armed_at = unbox.get('armed_at')
    if unbox.get('state') == 'armed' and isinstance(armed_at, int) and boot_time() > armed_at:
        write_unbox(state='unboxing', armed_at=armed_at, armed_by=unbox.get('armed_by', ''))
        unbox = unbox_info()
        log('First startup after preparing for unboxing: TLA Classic and the Welcome to TLA tour play at the next login.')
    for user, uid in graphical_sessions():
        if uid == 0 or not user:
            continue
        try:
            # (5.0: their background, and also any TLA Care request, and whether they've had the unboxing)
            r = as_user(user, uid, ['/usr/bin/python3', os.path.abspath(__file__), 'session-tick'], timeout=30)
        except Exception as e:
            log('Guard: %s' % e)
            continue
        info = dict(line.split('\t', 1) for line in r.stdout.splitlines() if '\t' in line)
        if info.get('care'):
            care_answer(user, *(info['care'].split('\t') + [''])[:2])
        if unbox.get('state') in ('armed', 'unboxing') and info.get('unboxshown') == str(unbox.get('armed_at')):
            write_unbox(state='done', armed_at=unbox.get('armed_at'), armed_by=unbox.get('armed_by', ''))
            unbox = unbox_info()
            log('Unboxing done (%s had the Welcome to TLA tour).' % user)


def session_tick():
    """The guard, in each person's session (5.0): their background, then hands over their TLA Care request (used up
    here) and whether they've had the unboxing."""
    apply_background(if_needed=True)
    st = state()
    if st.get('CareRequest'):
        set_state(CareRequest='')
        print('care\t%s\t%s' % (st.get('CareRequest'), st.get('CareRequestAt', '')))
    print('unboxshown\t%s' % st.get('UnboxShown', ''))


def care_answer(user, request, at):
    """Root (the guard): does what someone asked for in TLA Care, if it's on the list and was asked in the last 10
    minutes, and writes the answer for their window."""
    try:
        recent = 0 <= time.time() - int(at) <= 600
    except ValueError:
        recent = False
    if request not in CARE_REQUESTS or not recent:
        log('TLA Care: ignored a request (%r).' % request[:40])
        return

    def answer(text):
        os.makedirs(CARE_DIR, exist_ok=True)
        os.chmod(CARE_DIR, 0o755)
        with open(CARE_RESULT + '.tmp', 'w') as f:
            f.write('%s|%s|%s' % (request, at, text))
        os.chmod(CARE_RESULT + '.tmp', 0o644)
        os.replace(CARE_RESULT + '.tmp', CARE_RESULT)

    if request == 'cleanup':
        before = shutil.disk_usage('/').free
        for cmd in (['apt-get', 'clean'], ['journalctl', '--vacuum-time=14d']):
            try:
                subprocess.run(cmd, capture_output=True, timeout=300)
            except Exception:
                pass
        freed = shutil.disk_usage('/').free - before
        log('TLA Care: cleaned up for %s (%d MB).' % (user, freed // 1e6))
        answer('Freed %.1f GB.' % (freed / 1e9) if freed >= 1e8 else "Done. There wasn't much to clear: the rest is "
               'your own files and apps. To see what uses the space, open Disk Usage Analyzer.')
    elif request == 'videos':
        for f in ('.videos-ok', '.videos-checked'):
            try:
                os.remove(os.path.join(APP_DIR, f))
            except OSError:
                pass
        answer('Downloading now. Check again in a few minutes.')    # (the guard's next run, in 20 seconds)
    elif request == 'update':
        answer(check_update_now())      # (5.8.0: Check for updates)
    elif request == 'signin':
        # 5.7.0: a sign-in came back signed with a key the guard hasn't fetched yet: fetch the keys now (at most once a
        # minute, whoever asks).
        sync_signin(force=True)
        answer('Done.')
    elif request == 'unbox':
        if unbox_info().get('state') != 'ready':
            answer('This computer has already been prepared for unboxing.')
            return
        write_unbox(state='armed', armed_at=int(time.time()), armed_by=user)
        log('Prepared for unboxing by %s; shutting down.' % user)
        answer('Shutting down.')
        subprocess.Popen(['systemctl', 'poweroff'])


# ---- fallback player (no mpv) -----------------------------------------------------------------------------------
def gst_play(path, skip, mute, greet=''):
    """Plays the video full screen with GStreamer in a GTK window: GTK 3 (gtksink) or GTK 4 (gtk4paintablesink,
    which Ubuntu's own video player uses). Closes at the end, after 3 minutes at most, or (if allowed) on Esc,
    Space, Enter or a click. A greeting, if any, shows over the first 4.5 seconds."""
    import gi
    gi.require_version('Gst', '1.0')
    from gi.repository import Gst, GLib
    Gst.init(None)
    play = Gst.ElementFactory.make('playbin', None)
    if play is None:
        log('GStreamer has no playbin; the video can\'t play (installing mpv fixes this).')
        return 1
    play.set_property('uri', Gst.filename_to_uri(path))
    play.set_property('mute', mute)
    if mute:
        play.set_property('audio-sink', Gst.ElementFactory.make('fakesink', None))
    overlay = Gst.ElementFactory.make('textoverlay', None) if greet else None
    if overlay is not None:
        overlay.set_property('text', greet)
        overlay.set_property('font-desc', 'Sans Bold 20')
        overlay.set_property('valignment', 'bottom')
        overlay.set_property('halignment', 'center')
        overlay.set_property('ypad', 40)
        overlay.set_property('shaded-background', False)
        play.set_property('video-filter', overlay)
        GLib.timeout_add(4500, lambda: overlay.set_property('text', '') or False)
    sink = Gst.ElementFactory.make('gtksink', None)
    gtk_version = '3.0'
    if sink is None:
        sink = Gst.ElementFactory.make('gtk4paintablesink', None)
        gtk_version = '4.0'
    loop = GLib.MainLoop()
    done = {'rc': 0}

    def finish(*_):
        play.set_state(Gst.State.NULL)
        if loop.is_running():
            loop.quit()
        return False

    def on_message(_bus, msg):
        if msg.type == Gst.MessageType.EOS:
            finish()
        elif msg.type == Gst.MessageType.ERROR:
            log('GStreamer: %s' % msg.parse_error()[0].message)
            done['rc'] = 1
            finish()

    bus = play.get_bus()
    bus.add_signal_watch()
    bus.connect('message', on_message)
    GLib.timeout_add_seconds(180, finish)
    if sink is None:
        # No GTK video sink: GStreamer opens its own window.
        play.set_state(Gst.State.PLAYING)
        loop.run()
        return done['rc']
    try:
        gi.require_version('Gtk', gtk_version)
        from gi.repository import Gtk
        play.set_property('video-sink', sink)
        keys = ('Escape', 'space', 'Return', 'KP_Enter', 'q')
        if gtk_version == '3.0':
            from gi.repository import Gdk
            win = Gtk.Window(title='TLA BootPaper')
            try:
                g = Gdk.Display.get_default().get_primary_monitor() or Gdk.Display.get_default().get_monitor(0)
                r = g.get_geometry()
                win.set_default_size(r.width, r.height)
            except Exception:
                pass
            css = Gtk.CssProvider()
            css.load_from_data(b'window { background: black; }')
            win.get_style_context().add_provider(css, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)
            win.add(sink.get_property('widget'))
            win.set_keep_above(True)
            win.connect('delete-event', lambda *_: not skip or finish() or False)
            win.connect('key-press-event', lambda _w, e: skip and Gdk.keyval_name(e.keyval) in keys and finish())
            win.connect('button-press-event', lambda *_: skip and finish())
            win.add_events(Gdk.EventMask.BUTTON_PRESS_MASK)
            win.fullscreen()
            win.show_all()
            try:
                win.get_window().set_cursor(Gdk.Cursor.new_from_name(win.get_display(), 'none'))
            except Exception:
                pass
        else:
            from gi.repository import Gdk
            win = Gtk.Window(title='TLA BootPaper')
            css = Gtk.CssProvider()
            try:
                css.load_from_string('window { background: black; }')
            except Exception:
                css.load_from_data(b'window { background: black; }', -1)
            Gtk.StyleContext.add_provider_for_display(Gdk.Display.get_default(), css,
                                                      Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)
            win.set_child(Gtk.Picture.new_for_paintable(sink.get_property('paintable')))
            win.connect('close-request', lambda *_: not skip or finish() or False)
            k = Gtk.EventControllerKey()
            k.connect('key-pressed', lambda _c, kv, *_: skip and Gdk.keyval_name(kv) in keys and finish())
            win.add_controller(k)
            c = Gtk.GestureClick()
            c.connect('pressed', lambda *_: skip and finish())
            win.add_controller(c)
            win.set_cursor_from_name('none')
            win.fullscreen()
            win.present()
    except Exception as e:
        # The GTK window couldn't be set up: GStreamer opens its own window instead.
        log('GTK video window unavailable (%s); using a plain GStreamer window.' % e)
        play.set_property('video-sink', Gst.ElementFactory.make('autovideosink', None))
    play.set_state(Gst.State.PLAYING)
    loop.run()
    return done['rc']


# ---- the window -------------------------------------------------------------------------------------------------
def run_app(whats_new_only=False, ask_name_only=False, report_only=False, care_only=False, tour_only=False,
            sign_in=False):
    import gi
    gi.require_version('Gtk', '3.0')
    gi.require_version('GdkPixbuf', '2.0')
    from gi.repository import Gtk, GdkPixbuf, Gdk, Pango, GLib

    css = Gtk.CssProvider()
    css.load_from_data(b"""
      .tile { padding: 2px; border: 3px solid transparent; border-radius: 9px; background: none; box-shadow: none; }
      .tile:hover { border-color: alpha(currentColor, 0.25); }
      .tile.chosen { border-color: @theme_selected_bg_color; }
      .tile-name { margin-top: 4px; }
      .tile-name.chosen { font-weight: bold; }
      .note { background: #FFF4CE; color: #1F1F1F; border: 1px solid #F2D57C; border-radius: 6px; padding: 8px 12px; }
      .help { background: #E7F0FD; color: #102A4C; border: 1px solid #9CC3F5; border-radius: 6px; padding: 10px 14px; }
      .help link { color: #0B57D0; }
      .dim { opacity: 0.7; }
      .small { font-size: 0.85em; }
      .bottom { border-top: 1px solid alpha(currentColor, 0.15); padding: 12px 24px; }
      .preview { min-width: 28px; min-height: 28px; padding: 0; border-radius: 99px; border: 1px solid rgba(255,255,255,0.85);
                 background: rgba(0,0,0,0.65); color: white; box-shadow: none; }
      .preview:hover { background: #0F6CBD; }
      /* 5.9.0: their own pictures */
      .remove { min-width: 24px; min-height: 24px; padding: 0; border-radius: 99px; border: 1px solid rgba(255,255,255,0.85);
                background: rgba(0,0,0,0.65); color: white; box-shadow: none; }
      .remove:hover { background: #C42B1C; }
      .add-tile { min-width: 160px; min-height: 93px; padding: 0; border: 2px dashed alpha(currentColor, 0.35); border-radius: 9px;
                  background: alpha(currentColor, 0.04); box-shadow: none; }
      .add-tile:hover { border-color: @theme_selected_bg_color; background: alpha(@theme_selected_bg_color, 0.08); }
      /* 5.0: TLA Care, the unboxing box, the Welcome to TLA tour */
      .badge { min-width: 26px; min-height: 26px; border-radius: 13px; color: white; font-weight: bold; }
      .badge.ok { background: #107C10; } .badge.info { background: #0F6CBD; }
      .badge.warn { background: #C27C0E; } .badge.bad { background: #C42B1C; }
      .summary { border-radius: 6px; padding: 10px 14px; font-weight: bold; color: #1F1F1F; }
      .summary.ok { background: #DFF6DD; border: 1px solid #9FD89F; }
      .summary.warn { background: #FFF4CE; border: 1px solid #F2D57C; }
      .summary.bad { background: #FDE7E9; border: 1px solid #F1BBBC; }
      .unbox { background: #F3F0FB; color: #2B1F4D; border: 1px solid #C9BCEB; border-radius: 6px; padding: 12px 14px; }
      .tour-shade { background-image: linear-gradient(to right, rgba(8,20,38,0.95), rgba(8,20,38,0.80) 50%, rgba(8,20,38,0.30)); }
      .tour label { color: white; }
      .tour .kicker { color: #F2B830; font-weight: bold; }
      .tour .heading { font-size: 30pt; font-weight: bold; }
      .tour .body { font-size: 13pt; }
      .tour .dot { min-width: 8px; min-height: 8px; border-radius: 4px; background: rgba(255,255,255,0.45); }
      .tour .dot.now { min-width: 22px; background: #F2B830; }
      .tour button { background-image: none; border: none; box-shadow: none; border-radius: 20px; padding: 6px 20px;
                     background-color: rgba(255,255,255,0.2); color: white; }
      .tour button label { color: white; }
      .tour button.next { background-color: white; }
      .tour button.next label { color: #0B1B33; }
      .tour button.tile { background-color: rgba(0,0,0,0.25); padding: 2px; border-radius: 8px; border: 3px solid transparent; }
      .tour button.tile.chosen { border-color: #F2B830; }
      .tour entry { color: #1F1F1F; background-color: white; min-height: 34px; font-size: 13pt; border-radius: 8px; }
      /* 5.6.0: a new look: each section's options in a rounded card, switches, a coloured main button */
      .settings-page { background-color: shade(@theme_bg_color, 0.97); }
      .card { background-color: @theme_base_color; border: 1px solid alpha(currentColor, 0.12); border-radius: 12px;
              padding: 6px 18px; }
      .card-row { padding: 10px 0; }
      .card-row.line { border-top: 1px solid alpha(currentColor, 0.09); }
      .section { font-size: 15pt; font-weight: bold; margin-top: 18px; }
      .main-button { background-image: none; background-color: #0F6CBD; color: white; border-color: #0F6CBD; }
      .main-button label { color: white; }
      .main-button:hover { background-color: #115EA3; }
      .help, .note, .unbox { border-radius: 10px; }
      /* 5.7.0: signing in with the Hub account */
      .signin { background: #E7F0FD; color: #102A4C; border: 1px solid #9CC3F5; border-radius: 10px; padding: 12px 14px; }
      .signin.ok { background: #DFF6DD; color: #0E3B0E; border-color: #9FD89F; }
      .signin.warn { background: #FFF4CE; color: #3D2E00; border-color: #F2D57C; }
      .signin label { color: inherit; }
      .signin .err { color: #A4262C; }
      .signin .title { font-weight: bold; }
      .signin link { color: #0B57D0; }
    """)
    Gtk.StyleContext.add_provider_for_screen(Gdk.Screen.get_default(), css,
                                             Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)

    def label(text, size=None, bold=False, dim=False, wrap=False, small=False):
        l = Gtk.Label(xalign=0)
        markup = GLib.markup_escape_text(text)
        if bold:
            markup = '<b>%s</b>' % markup
        if size:
            markup = '<span size="%d">%s</span>' % (size * 1024, markup)
        l.set_markup(markup)
        if wrap:
            l.set_line_wrap(True)
            l.set_max_width_chars(80)
        if dim:
            l.get_style_context().add_class('dim')
        if small:
            l.get_style_context().add_class('small')
        return l

    class Toggle(Gtk.Box):
        """5.6.0: a label with an on/off switch at the right (used like the check box it replaces)."""
        def __init__(self, text):
            super().__init__(spacing=16)
            self.text = Gtk.Label(label=text, xalign=0)
            self.text.set_line_wrap(True)
            self.switch = Gtk.Switch(valign=Gtk.Align.CENTER)
            self.pack_start(self.text, True, True, 0)
            self.pack_end(self.switch, False, False, 0)

        def get_active(self):
            return self.switch.get_active()

        def set_active(self, on):
            self.switch.set_active(on)

        def connect(self, signal, handler, *args):
            if signal == 'toggled':
                return self.switch.connect('notify::active', lambda *_: handler(self, *args))
            return super().connect(signal, handler, *args)

    def card():
        """5.6.0: a rounded card; add() puts each thing in it on its own row, with a line between rows."""
        c = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        c.get_style_context().add_class('card')

        def add(widget, line=True):
            row = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
            row.get_style_context().add_class('card-row')
            if line and c.get_children():
                row.get_style_context().add_class('line')
            row.pack_start(widget, False, False, 0)
            c.pack_start(row, False, False, 0)
            return row
        c.add_row = add
        return c

    def section(text):
        l = label(text)
        l.get_style_context().add_class('section')
        return l

    def whats_new_window(parent=None):
        w = Gtk.Window(title="What's new in TLA BootPaper")
        w.set_default_size(620, 560)
        if parent:
            w.set_transient_for(parent)
        sc = Gtk.ScrolledWindow()
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6, margin=22)
        for title, items in release_notes():
            box.pack_start(label(title, 15, bold=True), False, False, 8)
            for item in items:
                parts = item.split('**')
                text = ''.join('<b>%s</b>' % GLib.markup_escape_text(p) if i % 2 else GLib.markup_escape_text(p)
                               for i, p in enumerate(parts))
                l = Gtk.Label(xalign=0)
                l.set_markup('•  ' + text)
                l.set_line_wrap(True)
                l.set_max_width_chars(70)
                box.pack_start(l, False, False, 0)
        sc.add(box)
        outer = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        outer.pack_start(sc, True, True, 0)
        bar = Gtk.Box(spacing=8)
        bar.get_style_context().add_class('bottom')
        if parent is None:
            open_btn = Gtk.Button(label='Open TLA BootPaper')
            open_btn.connect('clicked', lambda *_: (w.destroy(), subprocess.Popen(
                ['/usr/bin/python3', os.path.abspath(__file__), 'app'])))
            bar.pack_end(open_btn, False, False, 0)
        ok = Gtk.Button(label='Got it')
        ok.connect('clicked', lambda *_: w.destroy())
        bar.pack_end(ok, False, False, 0)
        bar.pack_start(label('Version %s · %s' % (shown_release(), dict(CHANNELS)[channel()]), dim=True, small=True),
                       False, False, 0)
        outer.pack_start(bar, False, False, 0)
        w.add(outer)
        w.show_all()
        return w

    def name_window():
        """Asks once (4.0) what name the intro video should greet them by."""
        w = Gtk.Window(title='TLA BootPaper')
        w.set_default_size(460, -1)
        w.set_position(Gtk.WindowPosition.CENTER)
        w.set_keep_above(True)
        icon = os.path.join(APP_DIR, 'AppIcon.png')
        if os.path.exists(icon):
            w.set_icon_from_file(icon)
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8, margin=24)
        box.pack_start(label('What should we call you?', 16, bold=True), False, False, 0)
        box.pack_start(label("Your intro video will greet you by this name, like “Good morning, Sam!” "
                             'You can change it any time in TLA BootPaper.', dim=True, wrap=True), False, False, 0)
        entry = Gtk.Entry(max_length=NAME_MAX, placeholder_text='Your preferred name')
        entry.set_text(str(setting('PreferredName')))
        box.pack_start(entry, False, False, 8)
        row = Gtk.Box(spacing=8)
        later = Gtk.Button(label='Not now')
        ok = Gtk.Button(label='Save')
        ok.get_style_context().add_class('suggested-action')
        row.pack_end(ok, False, False, 0)
        row.pack_end(later, False, False, 0)
        box.pack_start(row, False, False, 4)
        w.add(box)

        def save_name(*_):
            name = ' '.join(entry.get_text().split())[:NAME_MAX]
            if valid('PreferredName', name):
                save('PreferredName', name)
            set_state(NameAsked=1)
            w.destroy()

        def not_now(*_):
            set_state(NameAsked=1)
            w.destroy()
        ok.connect('clicked', save_name)
        entry.connect('activate', save_name)
        later.connect('clicked', not_now)
        w.show_all()
        return w

    def report_window(parent=None):
        """Report a problem (4.3): a short form, then a new email to the helpdesk with this computer's details."""
        from urllib.parse import quote
        w = Gtk.Window(title='Report a problem - TLA')
        w.set_default_size(580, -1)
        w.set_position(Gtk.WindowPosition.CENTER)
        if parent:
            w.set_transient_for(parent)
        icon = os.path.join(APP_DIR, 'AppIcon.png')
        if os.path.exists(icon):
            w.set_icon_from_file(icon)
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6, margin=24)
        head = Gtk.Box(spacing=14)
        if os.path.exists(icon):
            try:
                head.pack_start(Gtk.Image.new_from_pixbuf(GdkPixbuf.Pixbuf.new_from_file_at_scale(icon, 44, 44, True)),
                                False, False, 0)
            except Exception:
                pass
        head.pack_start(label('Report a problem', 18, bold=True), False, False, 0)
        box.pack_start(head, False, False, 0)
        box.pack_start(label("Tell the helpdesk what's wrong. This computer's details are added for you, so they can "
                             'find it and help faster.', dim=True, wrap=True), False, False, 4)
        box.pack_start(label("What's it about?", dim=True), False, False, 6)
        topic = Gtk.ComboBoxText()
        topic.set_halign(Gtk.Align.START)
        topic.append('', 'Choose one')
        for t in REPORT_TOPICS:
            topic.append(t, t)
        topic.set_active_id('')
        box.pack_start(topic, False, False, 0)
        box.pack_start(label('What happened?', dim=True), False, False, 6)
        sc = Gtk.ScrolledWindow(hscrollbar_policy=Gtk.PolicyType.NEVER)
        sc.set_shadow_type(Gtk.ShadowType.IN)
        sc.set_size_request(-1, 110)
        text = Gtk.TextView(wrap_mode=Gtk.WrapMode.WORD_CHAR, left_margin=6, right_margin=6, top_margin=5, bottom_margin=5)
        sc.add(text)
        box.pack_start(sc, False, False, 0)
        box.pack_start(label('What were you doing, and what did you expect to happen? Any error message helps. '
                             '(You can attach a screenshot to the email.)', dim=True, small=True, wrap=True), False, False, 0)
        box.pack_start(label('How much is it getting in the way?', dim=True), False, False, 6)
        blocking = Gtk.RadioButton.new_with_label_from_widget(None, "I can't do my work")
        annoying = Gtk.RadioButton.new_with_label_from_widget(blocking, 'I can still work around it')
        annoying.set_active(True)
        box.pack_start(blocking, False, False, 0)
        box.pack_start(annoying, False, False, 0)
        box.pack_start(label('Details about this computer that will be included', dim=True), False, False, 6)
        dsc = Gtk.ScrolledWindow(hscrollbar_policy=Gtk.PolicyType.NEVER)
        dsc.set_shadow_type(Gtk.ShadowType.IN)
        dsc.set_size_request(-1, 120)
        details = Gtk.TextView(editable=False, cursor_visible=False, wrap_mode=Gtk.WrapMode.WORD_CHAR, left_margin=6,
                               top_margin=5, bottom_margin=5)
        details.get_buffer().set_text('Collecting the details...')
        dsc.add(details)
        box.pack_start(dsc, False, False, 0)
        done = label('', wrap=True)
        box.pack_start(done, False, False, 6)
        row = Gtk.Box(spacing=8)
        copy_btn = Gtk.Button(label='Copy report')
        cancel = Gtk.Button(label='Cancel')
        send = Gtk.Button(label='Email the helpdesk')
        send.get_style_context().add_class('suggested-action')
        send.set_sensitive(False)
        row.pack_start(copy_btn, False, False, 0)
        row.pack_end(send, False, False, 0)
        row.pack_end(cancel, False, False, 0)
        box.pack_start(row, False, False, 8)
        w.add(box)

        def buf_text(tv):
            b = tv.get_buffer()
            return b.get_text(b.get_start_iter(), b.get_end_iter(), False)

        def ready(*_):
            send.set_sensitive(bool(topic.get_active_id()) and bool(buf_text(text).strip()))

        def content():
            return report_email(topic.get_active_id() or 'Something else', blocking.get_active(), buf_text(text),
                                buf_text(details))

        def say(msg):
            done.set_markup('<span foreground="#2E7D32">%s</span>' % GLib.markup_escape_text(msg))

        def to_clipboard(t):
            Gtk.Clipboard.get(Gdk.SELECTION_CLIPBOARD).set_text(t, -1)

        def open_uri(uri):
            try:
                Gtk.show_uri_on_window(w, uri, Gdk.CURRENT_TIME)
                return True
            except Exception:
                return False

        def on_send(*_):
            subject, body = content()
            if open_uri('mailto:%s?subject=%s&body=%s' % (HELPDESK, quote(subject), quote(body))):
                say('Your email to the helpdesk is ready in your mail app. Check it, add a screenshot if you like, '
                    'then press Send.')
            elif open_uri('https://outlook.office.com/mail/deeplink/compose?to=%s&subject=%s&body=%s'
                          % (quote(HELPDESK), quote(subject), quote(body))):
                say('Your email to the helpdesk is ready in Outlook on the web. Check it, then press Send.')
            else:
                to_clipboard(body)
                say("Couldn't open an email. Your report is on the clipboard: paste it into an email to %s." % HELPDESK)
            cancel.set_label('Close')

        def on_copy(*_):
            subject, body = content()
            to_clipboard('To: %s\nSubject: %s\n\n%s' % (HELPDESK, subject, body))
            say('Copied. Paste it into an email to %s.' % HELPDESK)

        topic.connect('changed', ready)
        text.get_buffer().connect('changed', ready)
        send.connect('clicked', on_send)
        copy_btn.connect('clicked', on_copy)
        cancel.connect('clicked', lambda *_: w.destroy())

        def fill_details():
            try:
                details.get_buffer().set_text('\n'.join('%s: %s' % x for x in device_details()))
            except Exception as e:
                details.get_buffer().set_text('Computer: %s\nTLA BootPaper: %s' % (platform.node(), RELEASE))
                log('Report details: %s' % e)
            return False
        GLib.timeout_add(150, fill_details)    # (once the window is showing)
        w.show_all()
        text.grab_focus()
        report_widgets.update(window=w, topic=topic, text=text, send=send, details=details)
        return w

    # ---- 5.0: TLA Care and the Welcome to TLA tour ----
    import threading

    def in_background(job, done):
        """Runs job() off the main loop (so the window keeps drawing), then done(its result) on it."""
        def run():
            try:
                r = job()
            except Exception as e:
                log('TLA Care: %s' % e)
                r = None
            GLib.idle_add(lambda: (done(r), False)[1])
        threading.Thread(target=run, daemon=True).start()

    def confirm(parent, title, text, yes):
        d = Gtk.MessageDialog(transient_for=parent, modal=True, message_type=Gtk.MessageType.QUESTION,
                              buttons=Gtk.ButtonsType.NONE, text=title)
        d.format_secondary_text(text)
        d.add_button('Cancel', Gtk.ResponseType.CANCEL)
        d.add_button(yes, Gtk.ResponseType.OK).get_style_context().add_class('destructive-action')
        d.set_default_response(Gtk.ResponseType.CANCEL)
        r = d.run()
        d.destroy()
        return r == Gtk.ResponseType.OK

    def tell(parent, title, text):
        d = Gtk.MessageDialog(transient_for=parent, modal=True, message_type=Gtk.MessageType.INFO,
                              buttons=Gtk.ButtonsType.OK, text=title)
        d.format_secondary_text(text)
        d.run()
        d.destroy()

    def restart_now(parent):
        if not confirm(parent, 'Restart your computer now?', 'Save your work first: open apps will close.', 'Restart'):
            return
        log('TLA Care: restarting.')
        # (GNOME's own way first, so apps can finish saving)
        for cmd in (['gnome-session-quit', '--reboot', '--no-prompt'], ['systemctl', 'reboot']):
            if shutil.which(cmd[0]):
                try:
                    if subprocess.run(cmd, capture_output=True, timeout=30).returncode == 0:
                        return
                except Exception:
                    pass
        tell(parent, "Couldn't restart", 'Restart from the menu at the top right of the screen.')

    def open_folder(parent, folder):
        try:
            Gtk.show_uri_on_window(parent, 'file://' + folder, Gdk.CURRENT_TIME)
            return True
        except Exception:
            return subprocess.call(['xdg-open', folder], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL) == 0

    def gigabytes(n):
        return '%.1f GB' % (n / 1e9) if n >= 1e8 else '%d MB' % max(1, n // 1e6)

    BADGES = {'ok': '✓', 'info': 'i', 'warn': '!', 'bad': '!'}

    def care_window(parent=None):
        """TLA Care (5.0): checks on this computer, each with a fix where there's one. Fixes that need root
        (clearing system caches, downloading the videos) go to the guard, which answers in CARE_RESULT."""
        w = Gtk.Window(title='TLA Care')
        w.set_default_size(640, -1)
        w.set_position(Gtk.WindowPosition.CENTER)
        if parent:
            w.set_transient_for(parent)
        icon = os.path.join(APP_DIR, 'AppIcon.png')
        if os.path.exists(icon):
            w.set_icon_from_file(icon)
        cw = {'open': True, 'busy': set(), 'notes': {}}
        w.connect('destroy', lambda *_: cw.update(open=False))
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6, margin=24)
        head = Gtk.Box(spacing=14)
        if os.path.exists(icon):
            try:
                head.pack_start(Gtk.Image.new_from_pixbuf(GdkPixbuf.Pixbuf.new_from_file_at_scale(icon, 44, 44, True)),
                                False, False, 0)
            except Exception:
                pass
        hv = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        hv.pack_start(label('TLA Care', 18, bold=True), False, False, 0)
        hv.pack_start(label('Checks on this computer, and fixes for common problems.', dim=True, wrap=True),
                      False, False, 0)
        head.pack_start(hv, True, True, 0)
        box.pack_start(head, False, False, 0)
        summary = label('Checking your computer…', wrap=True)
        summary.get_style_context().add_class('summary')
        box.pack_start(summary, False, False, 12)
        rows_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        box.pack_start(rows_box, False, False, 0)
        bar = Gtk.Box(spacing=8)
        report = Gtk.Button(label='Report a problem')
        again = Gtk.Button(label='Check again')
        close = Gtk.Button(label='Close')
        bar.pack_start(report, False, False, 0)
        bar.pack_end(close, False, False, 0)
        bar.pack_end(again, False, False, 0)
        box.pack_start(bar, False, False, 14)
        w.add(box)

        def show_rows(rows):
            if not cw['open']:
                return
            rows = rows or []
            for c in rows_box.get_children():
                c.destroy()
            bad = sum(r['status'] == 'bad' for r in rows)
            warn = sum(r['status'] == 'warn' for r in rows)
            ctx = summary.get_style_context()
            for k in ('ok', 'warn', 'bad'):
                ctx.remove_class(k)
            if bad:
                summary.set_text('One thing needs your attention.' if bad + warn == 1
                                 else '%d things need your attention.' % (bad + warn))
                ctx.add_class('bad')
            elif warn:
                summary.set_text('One thing to look at.' if warn == 1 else '%d things to look at.' % warn)
                ctx.add_class('warn')
            else:
                summary.set_text('Your computer is in good shape. ✓')
                ctx.add_class('ok')
            for i, r in enumerate(rows):
                if i:
                    rows_box.pack_start(Gtk.Separator(), False, False, 0)
                row = Gtk.Box(spacing=14, margin_top=10, margin_bottom=10)
                badge = Gtk.Label(label=BADGES.get(r['status'], 'i'))
                for k in ('badge', r['status']):
                    badge.get_style_context().add_class(k)
                badge.set_valign(Gtk.Align.START)
                row.pack_start(badge, False, False, 0)
                col = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
                col.pack_start(label(r['title'], bold=True, wrap=True), False, False, 0)
                col.pack_start(label(r['detail'], dim=True, wrap=True), False, False, 0)
                note = label(cw['notes'].get(r['id'], ''), small=True, wrap=True)
                note.set_no_show_all(not note.get_text())
                col.pack_start(note, False, False, 2)
                row.pack_start(col, True, True, 0)
                if r['action']:
                    b = Gtk.Button(label=r['action_text'])
                    b.set_valign(Gtk.Align.CENTER)
                    if r['status'] in ('warn', 'bad'):
                        b.get_style_context().add_class('suggested-action')
                    b.set_sensitive(r['action'] not in cw['busy'])
                    b.connect('clicked', lambda btn, rr=r, nn=note: act(rr, btn, nn))
                    row.pack_end(b, False, False, 0)
                rows_box.pack_start(row, False, False, 0)
            rows_box.show_all()
            again.set_sensitive(True)
            w.resize(w.get_allocated_width(), 1)       # (just as tall as what's in it)

        def check(*_):
            if not cw['open']:
                return
            again.set_sensitive(False)
            in_background(care_checks, show_rows)

        def say(r, note, text):
            cw['notes'][r['id']] = text
            if cw['open']:
                note.set_text(text)
                note.set_no_show_all(False)
                note.show()

        def finished(r, note, text, recheck=True):
            cw['busy'].discard(r['action'])
            say(r, note, text)
            if recheck:
                check()

        def wait_for(r, note, at, then, seconds=300):
            """Every second and a half: the guard's answer (it runs every 20 seconds)."""
            end = time.time() + seconds

            def poll():
                if not cw['open']:
                    return False
                res = care_result(r['action'], at)
                if res is None and time.time() < end:
                    return True
                then(res)
                return False
            GLib.timeout_add(1500, poll)

        def act(r, btn, note):
            a = r['action']
            if a == 'restart':
                restart_now(w)
            elif a == 'wifi':
                if not open_settings('wifi', 'network'):
                    say(r, note, 'Open Settings, then Wi-Fi.')
            elif a == 'fingerprint':
                say(r, note, 'In Settings, open Users (in newer versions: System, then Users) and turn on '
                             'Fingerprint Login.' if open_settings('system', 'users', 'user-accounts')
                    else 'Open Settings, then Users, and turn on Fingerprint Login.')
            elif a == 'report':
                report_window(w)
            elif a == 'audio':
                cw['busy'].add(a)
                btn.set_sensitive(False)
                say(r, note, 'Restarting the sound system…')
                in_background(fix_sound, lambda text: finished(r, note, text or "Couldn't restart the sound system."))
            elif a == 'cleanup':
                cw['busy'].add(a)
                btn.set_sensitive(False)
                say(r, note, 'Freeing up space…')

                def after_mine(freed):
                    freed = freed or 0
                    at = care_request('cleanup')
                    if not at:      # (installed for one person: only their own files)
                        finished(r, note, ('Cleared %s of old cached files. ' % gigabytes(freed) if freed >= 5e7
                                           else "There wasn't much to clear. ") +
                                 'To see what uses the space, open Disk Usage Analyzer.')
                        return

                    def answered(res):
                        text = res or "The computer didn't answer. Try again in a few minutes."
                        if res and freed >= 5e7:
                            text = text.rstrip('.') + ' (and %s of your own cached files).' % gigabytes(freed)
                        finished(r, note, text)
                    wait_for(r, note, at, answered)
                in_background(clear_my_cache, after_mine)
            elif a == 'videos':
                cw['busy'].add(a)
                btn.set_sensitive(False)
                at = care_request('videos')
                if at:
                    say(r, note, 'Asking for the downloads…')
                    wait_for(r, note, at, lambda res: finished(
                        r, note, res or "The computer didn't answer. Try again in a few minutes.", recheck=False))
                else:
                    subprocess.Popen([sys.executable, os.path.abspath(__file__), 'sync-videos'],
                                     stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
                    finished(r, note, 'Downloading now. Check again in a few minutes.', recheck=False)

        report.connect('clicked', lambda *_: report_window(w))
        again.connect('clicked', check)
        close.connect('clicked', lambda *_: w.destroy())
        w.connect('key-press-event', lambda win_, e: e.keyval == Gdk.KEY_Escape and (win_.destroy() or True))
        w.show_all()
        check()
        care_widgets.update(window=w)
        return w

    def tour_window():
        """The Welcome to TLA tour (5.0): at the unboxing (after TLA Classic), and any time from the app. A few
        pages over their background: their name, their background, fingerprint sign-in (5.1.5: only with a reader,
        for people who haven't added a fingerprint yet), call backgrounds, TLA Care. 5.2.5: full screen, with the
        content in the middle (what it opens, like Settings or TLA Care, still comes in front)."""
        W, H = 980, 620
        SW, SH = W, H
        try:
            display = Gdk.Display.get_default()
            geo = (display.get_primary_monitor() or display.get_monitor(0)).get_geometry()
            SW, SH = max(W, geo.width), max(H, geo.height)
        except Exception:
            pass
        w = Gtk.Window(title='Welcome to TLA')
        w.set_default_size(SW, SH)
        w.set_decorated(False)
        w.set_position(Gtk.WindowPosition.CENTER)
        w.fullscreen()
        # (it stays full screen: if it's taken out of full screen, it goes back)
        w.connect('window-state-event', lambda win_, e: (
            not (e.new_window_state & (Gdk.WindowState.FULLSCREEN | Gdk.WindowState.ICONIFIED)) and win_.fullscreen(), False)[1])
        icon = os.path.join(APP_DIR, 'AppIcon.png')
        if os.path.exists(icon):
            w.set_icon_from_file(icon)
        ov = Gtk.Overlay()
        pic = Gtk.Image()
        pic.set_size_request(SW, SH)
        ov.add(pic)
        shade = Gtk.Box()
        shade.get_style_context().add_class('tour-shade')
        ov.add_overlay(shade)
        content = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, margin_start=56, margin_end=48, margin_top=36,
                          margin_bottom=34, halign=Gtk.Align.CENTER, valign=Gtk.Align.CENTER)
        content.set_size_request(W - 56 - 48, H - 36 - 34)
        content.get_style_context().add_class('tour')
        ov.add_overlay(content)
        top = Gtk.Box()
        kicker = Gtk.Label(label='WELCOME TO TLA', xalign=0)
        kicker.get_style_context().add_class('kicker')
        skip = Gtk.Button(label='Skip')
        top.pack_start(kicker, False, False, 0)
        top.pack_end(skip, False, False, 0)
        content.pack_start(top, False, False, 0)
        mid = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12, valign=Gtk.Align.CENTER,
                      halign=Gtk.Align.START)
        heading = Gtk.Label(xalign=0)
        heading.set_line_wrap(True)
        heading.set_max_width_chars(28)
        heading.get_style_context().add_class('heading')
        body = Gtk.Label(xalign=0)
        body.set_line_wrap(True)
        body.set_max_width_chars(60)
        body.get_style_context().add_class('body')
        extra = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8, margin_top=8)
        mid.pack_start(heading, False, False, 0)
        mid.pack_start(body, False, False, 0)
        mid.pack_start(extra, False, False, 0)
        content.pack_start(mid, True, True, 0)
        bottom = Gtk.Box(spacing=10)
        dots = Gtk.Box(spacing=8, valign=Gtk.Align.CENTER)
        back = Gtk.Button(label='Back')
        nxt = Gtk.Button(label='Next')
        nxt.get_style_context().add_class('next')
        bottom.pack_start(dots, False, False, 0)
        bottom.pack_end(nxt, False, False, 0)
        bottom.pack_end(back, False, False, 0)
        content.pack_start(bottom, False, False, 0)
        w.add(ov)

        fp = fingerprint_state()
        can = users_can_change()
        pages = (['welcome'] + (['signin'] if signed_out() else []) + (['name'] if can else [])   # (6.1.5: signin) + (['background'] if can and not background_locked() else [])
                 + (['fingerprint'] if fp == 'reader' else []) + (['calls'] if released('calls') else [])
                 + (['care'] if released('care') else []) + ['done'])
        tw = {'i': 0, 'entry': None, 'note': None}

        def set_picture():
            try:
                pb = GdkPixbuf.Pixbuf.new_from_file(picture_files(current_background())[2])
                s = max(SW / pb.get_width(), SH / pb.get_height())
                pw, ph = max(SW, round(pb.get_width() * s)), max(SH, round(pb.get_height() * s))
                pb = pb.scale_simple(pw, ph, GdkPixbuf.InterpType.BILINEAR)
                pic.set_from_pixbuf(pb.new_subpixbuf((pw - SW) // 2, (ph - SH) // 2, SW, SH))
            except Exception as e:
                log('Tour picture: %s' % e)

        def save_name():
            if tw['entry'] is None:
                return
            name = ' '.join(tw['entry'].get_text().split())[:NAME_MAX]
            if valid('PreferredName', name) and name != setting('PreferredName'):
                save('PreferredName', name)

        def finish(*_):
            save_name()
            set_state(NameAsked=1, TourDone=today().isoformat())
            w.destroy()

        def go(step):
            if pages[tw['i']] == 'name':
                save_name()
            if step > 0 and tw['i'] == len(pages) - 1:
                finish()
                return
            tw['i'] = max(0, min(len(pages) - 1, tw['i'] + step))
            show()

        def button(text, handler):
            b = Gtk.Button(label=text)
            b.connect('clicked', handler)
            return b

        def extra_note():
            n = Gtk.Label(xalign=0)
            n.set_line_wrap(True)
            n.set_max_width_chars(70)
            tw['note'] = n
            return n

        def pick(bg_id):
            save('Background', bg_id)
            m = mine()
            if m.pop('TempBackground', None) is not None or m.pop('TempUntil', None) is not None:
                write_json(os.path.join(config_dir(), 'settings.json'), m)
            apply_background()
            set_picture()
            show()

        def on_pictures(*_):
            tw['note'].set_text('Getting the pictures ready…')
            in_background(call_pictures_folder, lambda folder: tw['note'] is not None and tw['note'].set_text(
                ('The pictures are open. In Teams on the web, choose More > Video effects > Add new; in Zoom, '
                 'Settings > Background & effects > +.') if folder and open_folder(w, folder)
                else "Couldn't open the pictures. They're in your Pictures folder, under TLA backgrounds."))

        def show():
            page = pages[tw['i']]
            for c in extra.get_children():
                c.destroy()
            tw['entry'] = tw['note'] = None
            name = ' '.join(str(setting('PreferredName')).split())
            if page == 'signin' and signed_out():      # (6.1.5)
                h = 'Sign in with your Hub account'
                b = 'Sign in once with the account you use for the TLA Hub. Until you do, your choices are greyed out and you see TLA Classic. Click Sign in: your browser opens the Hub’s sign-in page.'
                extra.pack_start(button('Sign in', lambda *_: (subprocess.Popen(
                    [sys.executable, os.path.abspath(__file__), 'app', '--signin'], start_new_session=True,
                    stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL), tw['note'].set_text(
                    'Finish signing in in your browser. When it says you’re signed in, come back here and click Next.'))),
                    False, False, 0)
                extra.pack_start(extra_note(), False, False, 0)
            elif page == 'signin':
                h = 'You’re signed in'
                b = 'Your choices are yours to make now. Let’s set them up.'
            elif page == 'welcome':
                h = 'Welcome to TLA, %s!' % name if name else 'Welcome to TLA!'
                b = ('This computer is all set up for you. Here’s a quick look at what makes it yours. It takes '
                     'about a minute.')
            elif page == 'name':
                h = 'What should we call you?'
                b = ('Your intro video greets you by name, like “Good morning, Sam!” You can change it any time in '
                     'TLA BootPaper.')
                e = Gtk.Entry(max_length=NAME_MAX, placeholder_text='Your preferred name', halign=Gtk.Align.START)
                e.set_width_chars(28)
                e.set_text(name)
                e.connect('activate', lambda *_: go(1))
                extra.pack_start(e, False, False, 0)
                tw['entry'] = e
            elif page == 'background':
                h = 'Pick your background'
                b = 'It goes on your desktop and lock screen. Each one has its own intro video' + (
                    ', and a light and a dark look that follow your style in Settings.' if released('lightdark') else '.')
                now, look, org_bg = current_background(), style(), org('Background')
                shown = [(i, n) for i, n in BACKGROUNDS if released(i) or i == org_bg]
                # 6.0.5: one themed section at a time, starting with the one their background is in.
                cats = [(c, n) for c, n in CATEGORIES if any(CATEGORY_OF.get(i, 'defaults') == c for i, _ in shown)]
                if tw.get('cat') not in [c for c, _ in cats]:
                    tw['cat'] = CATEGORY_OF.get(now, cats[0][0] if cats else 'defaults')
                tabs = Gtk.Box(spacing=8)
                for cid, cname in cats:
                    tb = Gtk.Button(label=cname)
                    if cid == tw['cat']:
                        tb.get_style_context().add_class('next')     # (the white one: the section showing)
                    tb.connect('clicked', lambda _b, c=cid: (tw.update(cat=c), show()))
                    tabs.pack_start(tb, False, False, 0)
                extra.pack_start(tabs, False, False, 0)
                grid = Gtk.FlowBox(selection_mode=Gtk.SelectionMode.NONE, homogeneous=True, column_spacing=6,
                                   row_spacing=4, max_children_per_line=6, min_children_per_line=6)
                for bg_id, bg_name in shown:
                    if CATEGORY_OF.get(bg_id, 'defaults') != tw['cat']:
                        continue
                    t = Gtk.Button()
                    t.get_style_context().add_class('tile')
                    try:
                        t.add(Gtk.Image.new_from_pixbuf(GdkPixbuf.Pixbuf.new_from_file_at_scale(
                            thumb_path(bg_id, look), 116, 65, False)))
                    except Exception:
                        t.add(Gtk.Label(label=bg_name))
                    t.set_tooltip_text(bg_name)
                    if bg_id == now:
                        t.get_style_context().add_class('chosen')
                    t.connect('clicked', lambda _b, i=bg_id: pick(i))
                    cap = Gtk.Label(label=bg_name + ('\n' + CAPTIONS[bg_id] if bg_id in CAPTIONS else ''))   # (6.1.0)
                    cap.set_justify(Gtk.Justification.CENTER)
                    cap.get_style_context().add_class('small')
                    cell = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
                    cell.pack_start(t, False, False, 0)
                    cell.pack_start(cap, False, False, 0)
                    grid.add(cell)
                grid.set_margin_top(12)
                extra.pack_start(grid, False, False, 0)
            elif page == 'fingerprint':
                h = 'Sign in with your fingerprint'
                b = ('This computer has a fingerprint reader. Add your fingerprint: it’s faster than typing your '
                     'password, and just as safe. You can do it any time in Settings, under Users.')
                row = Gtk.Box(spacing=10)
                row.pack_start(button('Set it up', lambda *_: tw['note'].set_text(
                    'In Settings, open Users (in newer versions: System, then Users) and turn on Fingerprint Login.'
                    if open_settings('system', 'users', 'user-accounts') else
                    'Open Settings, then Users, and turn on Fingerprint Login.')), False, False, 0)
                extra.pack_start(row, False, False, 0)
                extra.pack_start(extra_note(), False, False, 0)
            elif page == 'calls':
                h = 'Look great on calls'
                b = ('Use the TLA backgrounds on your video calls: open the pictures, then add them in Teams, Zoom or '
                     'your call app’s background settings.')
                row = Gtk.Box(spacing=10)
                row.pack_start(button('Open the pictures', on_pictures), False, False, 0)
                extra.pack_start(row, False, False, 0)
                extra.pack_start(extra_note(), False, False, 0)
            elif page == 'care':
                h = 'Help is one click away'
                b = ('TLA Care keeps an eye on this computer and fixes common problems for you: open it with Check my '
                     'computer in TLA BootPaper. Something not working? Click Report a problem: your computer’s '
                     'details go along, so the helpdesk can help faster.')
                row = Gtk.Box(spacing=10)
                row.pack_start(button('Check my computer', lambda *_: care_window(w).connect(
                    'destroy', lambda *_a: tour_widgets.get('last_closed', lambda: None)())), False, False, 0)
                extra.pack_start(row, False, False, 0)
            else:
                h = 'You’re all set!'
                b = 'Have a great year. You’ll find all of this again in TLA BootPaper: open Activities and type TLA.'
            heading.set_text(h)
            body.set_text(b)
            nxt.set_label('Get started' if page == 'done' else 'Let’s go' if page == 'welcome' else 'Next')
            back.set_visible(tw['i'] > 0)
            skip.set_visible(page != 'done')
            for d in dots.get_children():
                d.destroy()
            for i in range(len(pages)):
                d = Gtk.Box(valign=Gtk.Align.CENTER)
                d.get_style_context().add_class('dot')
                if i == tw['i']:
                    d.get_style_context().add_class('now')
                dots.pack_start(d, False, False, 0)
            extra.set_visible(bool(extra.get_children()))
            extra.show_all()
            dots.show_all()
            if tw['entry'] is not None:
                tw['entry'].grab_focus()
            else:
                nxt.grab_focus()

        nxt.connect('clicked', lambda *_: go(1))
        back.connect('clicked', lambda *_: go(-1))
        skip.connect('clicked', finish)
        w.connect('key-press-event', lambda _w, e: e.keyval == Gdk.KEY_Escape and (finish() or True))
        set_picture()
        w.show_all()
        show()
        w.present()
        tour_widgets.update(window=w, go=go, pages=pages)
        return w

    def snapshot_then_quit(path, delay=900):
        """Developer check: a picture of the screen (Xvfb), then quit."""
        GLib.timeout_add(delay, lambda: (os.system('xwd -root -silent | convert xwd:- "%s"' % path),
                                         Gtk.main_quit(), False)[2])

    report_widgets, care_widgets, tour_widgets = {}, {}, {}
    if care_only or tour_only:
        w = care_window() if care_only else tour_window()

        # 5.1.5: finished when the last window closes (whichever it is), so TLA Care opened from the tour (Check my
        # computer), or a report opened from TLA Care, stays open after the window it came from (it used to close too).
        def none_left():
            if any(x.get_visible() for x in Gtk.Window.list_toplevels() if x.get_window_type() == Gtk.WindowType.TOPLEVEL):
                return True
            Gtk.main_quit()
            return False

        def last_closed(*_):
            GLib.idle_add(none_left)
        w.connect('destroy', last_closed)
        tour_widgets['last_closed'] = last_closed
        GLib.timeout_add(1000, none_left)
        if os.environ.get('TLA_SNAPSHOT'):     # developer check (TLA_TOUR_PAGE: which page of the tour)
            if tour_only and os.environ.get('TLA_TOUR_PAGE') in tour_widgets['pages']:
                for _ in range(tour_widgets['pages'].index(os.environ['TLA_TOUR_PAGE'])):
                    tour_widgets['go'](1)
            snapshot_then_quit(os.environ['TLA_SNAPSHOT'], 2500 if care_only else 900)
        Gtk.main()
        return

    if report_only:
        w = report_window()
        w.connect('destroy', Gtk.main_quit)
        if os.environ.get('TLA_SNAPSHOT'):   # developer check
            def rsnap():
                report_widgets['topic'].set_active(1)
                report_widgets['text'].get_buffer().set_text('Sound stops after a few minutes.')
                GLib.timeout_add(700, lambda: (os.system('xwd -root -silent | convert xwd:- "%s"' % os.environ['TLA_SNAPSHOT']),
                                               Gtk.main_quit(), False)[2])
                return False
            GLib.timeout_add(800, rsnap)
        Gtk.main()
        return

    if whats_new_only or ask_name_only:
        w = whats_new_window() if whats_new_only else name_window()
        w.connect('destroy', Gtk.main_quit)
        Gtk.main()
        return

    win = Gtk.Window(title='TLA BootPaper')
    win.set_default_size(790, 860)
    icon = os.path.join(APP_DIR, 'AppIcon.png')
    if os.path.exists(icon):
        win.set_icon_from_file(icon)
    win.connect('destroy', Gtk.main_quit)
    ui = {'loading': False}

    page = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0, margin_start=28, margin_end=28,
                   margin_top=22, margin_bottom=18)
    # 5.6.0: the app's icon beside its name
    head = Gtk.Box(spacing=14)
    if os.path.exists(icon):
        try:
            head.pack_start(Gtk.Image.new_from_pixbuf(GdkPixbuf.Pixbuf.new_from_file_at_scale(icon, 52, 52, True)), False, False, 0)
        except Exception:
            pass
    head_text = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2, valign=Gtk.Align.CENTER)
    head_text.pack_start(label('TLA BootPaper', 22, bold=True), False, False, 0)
    head_text.pack_start(label('Choose how your welcome video plays and pick your background for the desktop and '
                               'lock screen.', dim=True, wrap=True), False, False, 0)
    head.pack_start(head_text, True, True, 0)
    page.pack_start(head, False, False, 0)
    # 5.7.0: signing in with their Hub account. Until they do, everything below is greyed out and they get TLA Classic.
    signin_box = Gtk.Box(spacing=14)
    signin_box.get_style_context().add_class('signin')
    sib = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
    signin_title = label('', wrap=True)
    signin_title.get_style_context().add_class('title')
    signin_text = label('', wrap=True)
    signin_err = label('', wrap=True, small=True)
    signin_err.get_style_context().add_class('err')
    for w in (signin_title, signin_text, signin_err):
        sib.pack_start(w, False, False, 0)
    signin_box.pack_start(sib, True, True, 0)
    signin_btns = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4, valign=Gtk.Align.CENTER)
    signin_btn = Gtk.Button(label='Sign in')
    signin_btn.get_style_context().add_class('main-button')
    signout_btn = Gtk.LinkButton.new_with_label('', 'Sign out')
    signin_btns.pack_start(signin_btn, False, False, 0)
    signin_btns.pack_start(signout_btn, False, False, 0)
    signin_box.pack_end(signin_btns, False, False, 0)
    page.pack_start(signin_box, False, False, 12)
    # The organization's announcement (4.0), if there is one.
    news_text = announcement()
    if news_text:
        news_note = Gtk.Label(xalign=0)
        news_note.set_markup('<b>Announcement:</b> ' + GLib.markup_escape_text(news_text))
        news_note.set_line_wrap(True)
        news_note.get_style_context().add_class('note')
        page.pack_start(news_note, False, False, 10)
    # Where to send requests, bug reports and ideas (3.4.5): always shown, near the top. The email starts with
    # this computer's details (4.0).
    help_markup = ("<b>Something not working?</b> Report it here and your computer's details go along with it. "
                   'For new background requests and ideas, email <a href="%s">%s</a>.')
    help_box = Gtk.Box(spacing=14)
    help_box.get_style_context().add_class('help')
    help_note = Gtk.Label(xalign=0)
    help_note.set_markup(help_markup % (GLib.markup_escape_text(helpdesk_link()), HELPDESK))
    help_note.set_line_wrap(True)
    help_box.pack_start(help_note, True, True, 0)
    # 4.3: Report a problem. 5.0: and TLA Care ("Check my computer") under it.
    help_btns = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6, valign=Gtk.Align.CENTER)
    report_btn = Gtk.Button(label='Report a problem')
    report_btn.connect('clicked', lambda *_: report_window(win))
    care_btn = Gtk.Button(label='Check my computer')
    care_btn.connect('clicked', lambda *_: care_window(win))
    help_btns.pack_start(report_btn, False, False, 0)
    help_btns.pack_start(care_btn, False, False, 0)
    help_box.pack_end(help_btns, False, False, 0)
    page.pack_start(help_box, False, False, 12)
    note = Gtk.Label(label="Your organization manages these settings, so they can't be changed here.", xalign=0)
    note.set_line_wrap(True)
    note.get_style_context().add_class('note')
    page.pack_start(note, False, False, 12)

    page.pack_start(section('Welcome video'), False, False, 8)
    video_card = card()
    enabled = Toggle('Play the welcome video when I log in')
    video_card.add_row(enabled, line=False)
    opts = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
    video_card.add_row(opts)

    def opt_row(text, widget):
        """A label on the left and its menu on the right."""
        r = Gtk.Box(spacing=16)
        r.pack_start(label(text), True, True, 0)
        r.pack_end(widget, False, False, 0)
        return r
    video = Gtk.ComboBoxText()
    for vid, name in VIDEOS:
        video.append(vid, name)
    opts.pack_start(opt_row('Which video', video), False, False, 4)
    opts.pack_start(label('When to play it'), False, False, 10)
    radios, group = {}, None
    for pid, name in PLAY_WHEN:
        r = Gtk.RadioButton.new_with_label_from_widget(group, name)
        group = group or r
        radios[pid] = r
        opts.pack_start(r, False, False, 1)
    sound = Toggle('Play with sound')
    skip = Toggle('Let me close it early with Esc or a click')
    opts.pack_start(Gtk.Separator(), False, False, 10)
    opts.pack_start(sound, False, False, 2)
    opts.pack_start(Gtk.Separator(), False, False, 10)
    opts.pack_start(skip, False, False, 2)
    opts.pack_start(Gtk.Separator(), False, False, 10)
    # Quiet hours (4.0): off unless they turn it on.
    quiet = Gtk.ComboBoxText()
    for qid, name in QUIET_MODES:
        quiet.append(qid, name)
    opts.pack_start(opt_row('Quiet hours (for class time)', quiet), False, False, 2)
    hours = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6, margin_start=4)
    times = Gtk.Box(spacing=8)
    q_start, q_end = Gtk.ComboBoxText(), Gtk.ComboBoxText()
    for t in TIMES:
        q_start.append(t, t)
        q_end.append(t, t)
    times.pack_start(label('From'), False, False, 0)
    times.pack_start(q_start, False, False, 0)
    times.pack_start(label('to'), False, False, 0)
    times.pack_start(q_end, False, False, 0)
    hours.pack_start(times, False, False, 0)
    day_row = Gtk.Box(spacing=4)
    day_buttons = {}
    for d in DAYS:
        b = Gtk.ToggleButton(label=d)
        day_buttons[d] = b
        day_row.pack_start(b, False, False, 0)
    hours.pack_start(day_row, False, False, 0)
    opts.pack_start(hours, False, False, 0)
    # The greeting (4.0; 5.6.0: on or off, keeping the name).
    opts.pack_start(Gtk.Separator(), False, False, 10)
    greet_on = Toggle('Greet me by name when the video starts')
    opts.pack_start(greet_on, False, False, 2)
    name_row = Gtk.Box(spacing=8, margin_top=8)
    name_row.pack_start(label('Your name', dim=True), False, False, 0)
    name_entry = Gtk.Entry(max_length=NAME_MAX, placeholder_text='Your preferred name')
    name_entry.set_width_chars(24)
    name_row.pack_start(name_entry, False, False, 0)
    # 4.0.5: a Save button and a line saying it's saved (Enter saves too, and so does closing the window).
    name_save = Gtk.Button(label='Save')
    name_save.set_sensitive(False)
    name_row.pack_start(name_save, False, False, 0)
    name_status = label('', small=True, wrap=True)
    name_row.pack_start(name_status, False, False, 0)
    opts.pack_start(name_row, False, False, 0)
    name_hint = label('', dim=True, small=True, wrap=True)
    opts.pack_start(name_hint, False, False, 4)
    last = label('', dim=True, wrap=True, small=True)
    video_card.add_row(last)
    page.pack_start(video_card, False, False, 4)

    page.pack_start(section('Background'), False, False, 8)
    bg_note = label('', dim=True, wrap=True)
    page.pack_start(bg_note, False, False, 2)
    # 4.2: how long a pick lasts (not saved) and how the picture fits the screen; a note while a pick is temporary.
    opt_row_box = Gtk.FlowBox(selection_mode=Gtk.SelectionMode.NONE, max_children_per_line=3, column_spacing=24,
                              row_spacing=8)
    pick_for, fit_choice = Gtk.ComboBoxText(), Gtk.ComboBoxText()
    for pid, pname in PICK_FOR:
        pick_for.append(pid, pname)
    pick_for.set_active_id('Always')
    for fid, fname, _ in FITS:
        fit_choice.append(fid, fname)
    # 5.0: light or dark.
    light_dark = Gtk.ComboBoxText()
    for lid, lname in LIGHT_DARK:
        light_dark.append(lid, lname)
    opt_cols = {}
    for title, combo in (('Use my pick', pick_for), ('Fit on the screen', fit_choice), ('Light or dark', light_dark)):
        col = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        col.pack_start(label(title, dim=True), False, False, 0)
        col.pack_start(combo, False, False, 0)
        opt_row_box.add(col)
        opt_cols[title] = col
    bg_card = card()
    bg_card.add_row(opt_row_box, line=False)
    page.pack_start(bg_card, False, False, 8)
    temp_box = Gtk.Box(spacing=8)
    temp_box.get_style_context().add_class('help')
    temp_text = label('', wrap=True)
    temp_end = Gtk.LinkButton.new_with_label('', 'Go back now')
    temp_box.pack_start(temp_text, False, False, 0)
    temp_box.pack_start(temp_end, False, False, 0)
    page.pack_start(temp_box, False, False, 6)

    tiles = {}

    def with_preview(btn, vid, name):
        """4.2: a play button on the picture of a background with an intro video: previews it without picking it."""
        if vid not in VIDEO_HASHES or not os.path.exists(video_path(vid)):
            return btn
        ov = Gtk.Overlay(halign=Gtk.Align.CENTER, valign=Gtk.Align.START)   # (just the picture's size)
        ov.add(btn)
        pv = Gtk.Button.new_from_icon_name('media-playback-start-symbolic', Gtk.IconSize.BUTTON)
        pv.get_style_context().add_class('preview')
        pv.set_halign(Gtk.Align.END)
        pv.set_valign(Gtk.Align.END)
        pv.set_margin_end(12)
        pv.set_margin_bottom(12)
        pv.set_tooltip_text('Play the %s video' % name)
        pv.connect('clicked', lambda *_: (play_video(force=True, vid=vid), refresh()))
        ov.add_overlay(pv)
        return ov

    def tile_grid():
        fb = Gtk.FlowBox(selection_mode=Gtk.SelectionMode.NONE, homogeneous=True, column_spacing=10,
                         row_spacing=10, max_children_per_line=8, min_children_per_line=2)
        return fb

    def tile_picture(bg_id, look):
        """The picture on a background's tile, in the light or dark look showing now (5.0)."""
        t = thumb_path(bg_id, look)
        if is_own(bg_id):
            # (5.9.0: their own picture, filling the tile's shape: the middle of it, not squashed)
            try:
                _, w, h = GdkPixbuf.Pixbuf.get_file_info(t)
                f = max(154 / w, 87 / h)
                pb = GdkPixbuf.Pixbuf.new_from_file_at_scale(t, max(154, round(w * f)), max(87, round(h * f)), False)
                return pb.new_subpixbuf((pb.get_width() - 154) // 2, (pb.get_height() - 87) // 2, 154, 87).copy()
            except Exception:
                return None
        try:
            return GdkPixbuf.Pixbuf.new_from_file_at_scale(t if os.path.exists(t) else background_path(bg_id, look),
                                                           154, 87, False)
        except Exception:
            return None

    # 6.0.5: a section for each theme (5.9.0 had Animals), each with a note naming the ones still waiting for their own
    # intro video.
    cat_grids = {c: tile_grid() for c, _ in CATEGORIES}
    cells, tile_imgs = {}, {}
    ui['look'] = style()
    for bg_id, name in BACKGROUNDS + [(SURPRISE, 'Surprise me')]:
        btn = Gtk.Button()
        btn.set_relief(Gtk.ReliefStyle.NONE)
        btn.get_style_context().add_class('tile')
        pb = tile_picture(bg_id, ui['look'])
        if pb:
            tile_imgs[bg_id] = Gtk.Image.new_from_pixbuf(pb)
            btn.add(tile_imgs[bg_id])
        else:
            btn.add(Gtk.Label(label=name))
        btn.set_tooltip_text('A different background every day' if bg_id == SURPRISE
                             else '%s: for our beta testers on the Experimental channel. It plays the TLA Classic video.' % name
                             if bg_id in CHANNEL_ONLY
                             else '%s: its own intro video is coming soon. Until then, it plays the TLA Classic video.' % name
                             if bg_id not in VIDEO_HASHES
                             else '%s: an intro video for light and one for dark' % name
                             if '%s-%s' % (bg_id, VARIANTS.get(bg_id, '')) in VIDEO_HASHES
                             else '%s: one intro video for light and dark' % name)
        cap = Gtk.Label(label=name + ('\n' + CAPTIONS[bg_id] if bg_id in CAPTIONS else ''))   # (6.1.0: "Linux default")
        cap.set_justify(Gtk.Justification.CENTER)
        cap.get_style_context().add_class('tile-name')
        cell = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        cell.pack_start(with_preview(btn, bg_id, name), False, False, 0)
        cell.pack_start(cap, False, False, 0)
        btn.connect('clicked', lambda _b, i=bg_id: on_background(i))
        cat_grids[CATEGORY_OF.get(bg_id, 'defaults')].add(cell)
        tiles[bg_id] = (btn, cap)
        cells[bg_id] = cell
    # The seasonal theme, while it's on: click it to go back to it after picking your own.
    seasonal_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
    theme_now = season()
    if theme_now:
        seasonal_box.pack_start(label('Seasonal', dim=True), False, False, 8)
        sgrid = tile_grid()
        sbtn = Gtk.Button()
        sbtn.set_relief(Gtk.ReliefStyle.NONE)
        sbtn.get_style_context().add_class('tile')
        spb = tile_picture(theme_now, ui['look'])
        if spb:
            tile_imgs['__season'] = Gtk.Image.new_from_pixbuf(spb)
            sbtn.add(tile_imgs['__season'])
        else:
            sbtn.add(Gtk.Label(label=BG_NAMES[theme_now]))
        sbtn.set_tooltip_text('Until %s' % SEASON_ENDS[theme_now])
        scap = Gtk.Label(label=BG_NAMES[theme_now])
        scap.get_style_context().add_class('tile-name')
        scell = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        scell.pack_start(with_preview(sbtn, theme_now, BG_NAMES[theme_now]), False, False, 0)
        scell.pack_start(scap, False, False, 0)
        sgrid.add(scell)
        seasonal_box.pack_start(sgrid, False, False, 0)
        sbtn.connect('clicked', lambda *_: on_seasonal())
        tiles['__season'] = (sbtn, scap)
    page.pack_start(seasonal_box, False, False, 0)
    cat_boxes = {}
    for cid, cname in CATEGORIES:
        cat_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        cat_box.pack_start(label(cname, dim=True), False, False, 8)
        cat_note = label('', dim=True, small=True, wrap=True)
        cat_note.set_no_show_all(True)
        cat_box.pack_start(cat_note, False, False, 0)
        cat_box.pack_start(cat_grids[cid], False, False, 0)
        page.pack_start(cat_box, False, False, 0)
        cat_boxes[cid] = (cat_box, cat_note)
    # 5.9.0: their own pictures, on a computer of their own (see own_pictures_allowed): a tile for each, with a
    # button to remove it, and "Add a picture" after them.
    own_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
    own_box.pack_start(label('Your own pictures', dim=True), False, False, 8)
    own_box.pack_start(label('This is your own computer, so you can use your own pictures too. They play the TLA '
                             'Classic video.', dim=True, small=True, wrap=True), False, False, 0)
    own_grid = tile_grid()
    own_box.pack_start(own_grid, False, False, 6)
    own_msg = label('', small=True, wrap=True)
    own_box.pack_start(own_msg, False, False, 0)
    own_msg.set_no_show_all(True)
    add_btn = Gtk.Button()
    add_btn.get_style_context().add_class('add-tile')
    add_inside = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2, valign=Gtk.Align.CENTER)
    add_inside.pack_start(Gtk.Image.new_from_icon_name('list-add-symbolic', Gtk.IconSize.DND), False, False, 0)
    add_btn.add(add_inside)
    add_btn.set_tooltip_text('Add a picture of your own (JPEG, PNG and most other kinds)')
    add_cap = Gtk.Label(label='Add a picture')
    add_cap.get_style_context().add_class('tile-name')
    add_cell = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, halign=Gtk.Align.CENTER)
    add_cell.pack_start(add_btn, False, False, 0)
    add_cell.pack_start(add_cap, False, False, 0)
    own_grid.add(add_cell)
    own_cells = {}
    page.pack_start(own_box, False, False, 0)
    own_box.set_no_show_all(True)

    # 5.0: Calls and reminders (TLA backgrounds for video calls, TLA Care's reminders).
    extras = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
    extras.pack_start(section('Calls and reminders'), False, False, 4)
    extras_card = card()
    calls_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
    calls_box.pack_start(label('Call backgrounds', bold=True), False, False, 0)
    calls_box.pack_start(label('Use the TLA backgrounds, light and dark, on your video calls. Open the pictures, then '
                               'add them in your call app: in Teams on the web, More > Video effects > Add new; in '
                               'Zoom, Settings > Background & effects > +.', wrap=True), False, False, 0)
    calls_row = Gtk.Box(spacing=10)
    calls_open = Gtk.Button(label='Open the pictures')
    calls_note = label('', dim=True, small=True, wrap=True)
    calls_row.pack_start(calls_open, False, False, 0)
    calls_row.pack_start(calls_note, False, False, 0)
    calls_box.pack_start(calls_row, False, False, 2)
    calls_row_wrap = extras_card.add_row(calls_box, line=False)
    reminders = Toggle('Remind me when my computer needs attention (TLA Care)')
    reminders_wrap = extras_card.add_row(reminders)
    extras.pack_start(extras_card, False, False, 4)
    page.pack_start(extras, False, False, 0)

    # 4.3: release channels.
    page.pack_start(section('Updates'), False, False, 4)
    page.pack_start(label('Choose when new backgrounds, intro videos and features reach you.', dim=True, wrap=True),
                    False, False, 4)
    updates_card = card()
    chan_radios, cgroup = {}, None
    chan_text = {'stable': ('Stable (recommended)', "New things arrive once they've been tried out."),
                 'experimental': ('Experimental', 'Get new backgrounds and features first. They might still have rough edges.')}
    for cid, cname in CHANNELS:
        title, sub = chan_text.get(cid, (cname, ''))
        r = Gtk.RadioButton.new_from_widget(cgroup)
        cgroup = cgroup or r
        rl = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        rl.pack_start(label(title), False, False, 0)
        rl.pack_start(label(sub, dim=True, small=True, wrap=True), False, False, 0)
        r.add(rl)
        chan_radios[cid] = r
        updates_card.add_row(r, line=bool(chan_radios) and len(chan_radios) > 1)
    chan_status = label('', dim=True, wrap=True)
    updates_card.add_row(chan_status)
    # 5.8.0: Check for updates.
    upd_box = Gtk.Box(spacing=14)
    upd_text = label('New versions install by themselves. To get one straight away, check now.', dim=True, wrap=True)
    upd_text.set_xalign(0)
    upd_box.pack_start(upd_text, True, True, 0)
    upd_btn = Gtk.Button(label='Check for updates')
    upd_btn.set_valign(Gtk.Align.CENTER)
    upd_box.pack_end(upd_btn, False, False, 0)
    # 6.1.0: a progress bar while an update installs, and a button that opens the new version once it's in.
    upd_bar = Gtk.ProgressBar()
    upd_bar.set_no_show_all(True)
    upd_restart = Gtk.Button(label='Restart TLA BootPaper', halign=Gtk.Align.START)
    upd_restart.set_no_show_all(True)
    upd_v = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
    upd_v.pack_start(upd_box, False, False, 0)
    upd_v.pack_start(upd_bar, False, False, 0)
    upd_v.pack_start(upd_restart, False, False, 0)
    upd_wrap = updates_card.add_row(upd_v)
    upd_wrap.set_no_show_all(True)     # (shown by refresh() once it's out on their channel)
    page.pack_start(updates_card, False, False, 6)
    # 5.0: Prepare for initial unboxing, only on a computer that hasn't been prepared (or handed out) yet.
    unbox_box = Gtk.Box(spacing=14)
    unbox_box.get_style_context().add_class('unbox')
    ubv = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
    ubv.pack_start(label('Setting this computer up for someone?', bold=True), False, False, 0)
    ubv.pack_start(label('When you’re done, click Prepare for initial unboxing. The computer shuts down, and the next '
                         'time it starts, whoever logs in gets the TLA Classic intro and the Welcome to TLA tour. This '
                         'can only be done once.', wrap=True), False, False, 0)
    unbox_box.pack_start(ubv, True, True, 0)
    unbox_btn = Gtk.Button(label='Prepare for initial unboxing')
    unbox_btn.set_valign(Gtk.Align.CENTER)
    unbox_box.pack_end(unbox_btn, False, False, 0)
    page.pack_start(unbox_box, False, False, 14)

    scroll = Gtk.ScrolledWindow(hscrollbar_policy=Gtk.PolicyType.NEVER)
    scroll.add(page)
    scroll.get_style_context().add_class('settings-page')

    bar = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
    bar.get_style_context().add_class('bottom')
    row = Gtk.Box(spacing=8)
    reset = Gtk.LinkButton.new_with_label('', "Use my organization's settings")
    news = Gtk.LinkButton.new_with_label('', "What's new")
    tour_link = Gtk.LinkButton.new_with_label('', 'Take the Welcome to TLA tour')     # (5.0)
    play_btn = Gtk.Button(label='Play video now')
    play_btn.get_style_context().add_class('main-button')
    close = Gtk.Button(label='Close')
    row.pack_start(reset, False, False, 0)
    row.pack_start(news, False, False, 0)
    row.pack_start(tour_link, False, False, 0)
    row.pack_end(close, False, False, 0)
    row.pack_end(play_btn, False, False, 0)
    bar.pack_start(row, False, False, 0)
    vrow = Gtk.Box(spacing=8)
    version_label = label('', dim=True, small=True)
    vrow.pack_start(version_label, False, False, 0)
    play_quiet = Gtk.LinkButton.new_with_label('', 'Play without sound')     # (4.2)
    vrow.pack_end(play_quiet, False, False, 0)
    # 5.6.0: the staff page (the lock screen announcement, and who uses what), behind TLA staff's Microsoft sign-in
    staff_link = Gtk.LinkButton.new_with_label(STAFF_PAGE, 'TLA staff')
    vrow.pack_start(staff_link, False, False, 0)
    bar.pack_start(vrow, False, False, 0)

    outer = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
    outer.pack_start(scroll, True, True, 0)
    outer.pack_start(bar, False, False, 0)
    win.add(outer)

    def refresh_signin():
        """5.7.0: the sign-in box: not there unless sign-in is switched on; otherwise who's signed in and until when,
        or why to sign in."""
        si = signin_now()
        signin_box.set_visible(si['state'] != 'off')
        if si['state'] == 'off':
            return
        ctx = signin_box.get_style_context()
        for c in ('ok', 'warn'):
            ctx.remove_class(c)
        name = si.get('name') or si.get('who') or ''
        btn, out = 'Sign in again', False
        if ui.get('signin_listener'):
            title = 'Finish signing in in your browser'
            text = 'Sign in with your Hub account in the browser tab that opened. This window updates when you’re done.'
            btn = 'Cancel'
        elif ui.get('signin_wait'):
            title, text, btn = 'Finishing signing in…', 'This takes a few seconds.', ''
        elif si['state'] == 'out':
            out = True
            if si.get('reason') == 'expired':
                title = 'Your TLA BootPaper sign-in has run out'
                text = ('Sign in again with your Hub account to get your welcome video and background back. Until then '
                        'you’ll see TLA Classic.')
            else:
                title = 'Sign in to use TLA BootPaper'
                text = ('Sign in with your Hub account to choose your welcome video and background. Until then '
                        'you’ll see TLA Classic.')
            btn = 'Sign in'
        elif si['state'] == 'grace':
            ctx.add_class('warn')
            title = 'Your TLA BootPaper sign-in has run out'
            text = ('This computer is offline, so your settings stay for %d more day%s. Sign in again once you’re '
                    'back online.' % (si['days'], '' if si['days'] == 1 else 's'))
        elif si['state'] == 'renew':
            ctx.add_class('warn')
            title = 'Signed in as %s' % name
            text = ('Your sign-in runs out %s (%s). Sign in again to keep your settings for another month.'
                    % ('tomorrow' if si['days'] <= 1 else 'in %d days' % si['days'], signin_when(si['until'])))
        else:
            ctx.add_class('ok')
            title = 'Signed in as %s' % name
            text = 'Until %s. You can sign in again from %s.' % (
                signin_when(si['until']), signin_when(si['until'] - signin_settings()['renewDays'] * 86400))
            btn = ''
        signin_title.set_text(title)
        signin_text.set_text(text)
        signin_err.set_text(ui.get('signin_msg') or '')
        signin_err.set_visible(bool(ui.get('signin_msg')))
        signin_btn.set_label(btn or 'Sign in')
        signin_btn.set_visible(bool(btn))
        signout_btn.set_visible(not out and not ui.get('signin_listener') and not ui.get('signin_wait'))

    def refresh():
        ui['loading'] = True
        refresh_signin()
        locked = not users_can_change() or signed_out()     # (5.7.0: greyed out until they sign in)
        calls_open.set_sensitive(not signed_out())           # (6.1.5)
        bg_locked = background_locked()
        note.set_visible(not users_can_change())
        enabled.set_active(setting('Enabled') == 1)
        sound.set_active(setting('Sound') == 1)
        skip.set_active(setting('AllowSkip') == 1)
        radios[setting('PlayWhen')].set_active(True)
        bg = setting('Background')
        now_bg = current_background()
        theme = season()
        seasonal_on = bool(theme) and now_bg == theme
        org_video = org('Video')
        video.remove_all()
        for vid, name in VIDEOS:
            if not released(vid) and vid != org_video:     # (4.3: only what's out on their channel)
                continue
            text = name
            if vid == 'match':
                match = match_video()
                text += ' (%s)' % (BG_NAMES[match] if os.path.exists(video_path(match)) else 'TLA Classic')
            if vid == org_video:
                text += ' - default'
            video.append(vid, text)
        video.set_active_id(setting('Video'))
        enabled.set_sensitive(not locked)
        on = not locked and setting('Enabled') == 1
        for c in [video, sound, skip, quiet, name_entry] + list(radios.values()):
            c.set_sensitive(on)
        quiet.set_active_id(setting('QuietMode'))
        q_start.set_active_id(setting('QuietStart'))
        q_end.set_active_id(setting('QuietEnd'))
        chosen_days = setting('QuietDays').split(',')
        for d, b in day_buttons.items():
            b.set_active(d in chosen_days)
            b.set_sensitive(on)
        q_start.set_sensitive(on)
        q_end.set_sensitive(on)
        hours.set_visible(setting('QuietMode') == 'Hours')
        # 5.6.0: the greeting on or off (their name stays), once that's out on their channel
        greet_switch = released('greeting-switch')
        greet_yes = not greet_switch or setting('Greeting') != 0
        greet_on.set_visible(greet_switch)
        greet_on.set_active(greet_yes)
        greet_on.set_sensitive(on)
        name_entry.set_sensitive(on and greet_yes)
        name_hint.set_text('The video says “Good morning” with your name. Leave it empty and save for no greeting.'
                           if not greet_switch else
                           'The video says “Good morning” with your name, in the style of its theme. Turned off, the '
                           'greeting doesn’t show and your name stays saved.' if released('greeting-styles') else
                           'The video says “Good morning” with your name. Turned off, the greeting doesn’t show and '
                           'your name stays saved.')
        if name_entry.get_text() != setting('PreferredName') and not name_entry.has_focus():
            name_entry.set_text(setting('PreferredName'))
        name_save.set_sensitive(on and typed_name() != setting('PreferredName'))
        st = state()
        last.set_text('Your video last played %s.' % st['LastPlayed'] if st.get('LastPlayed')
                      else "The video hasn't played for you on this computer yet.")
        if bg_locked:
            text = "Another policy on this computer locks the desktop picture, so the background can't be changed here."
        elif seasonal_on:
            text = ("It's %s time! Your desktop and lock screen show the %s theme until %s. Pick a background below "
                    'to use your own instead.' % (BG_NAMES[theme].lower() if theme == 'fall' else BG_NAMES[theme],
                                                  BG_NAMES[theme], SEASON_ENDS[theme]))
        elif theme:
            text = ('Your background is used for your desktop and lock screen. Click the %s theme to use it until %s.'
                    % (BG_NAMES[theme], SEASON_ENDS[theme]))
        elif bg == SURPRISE:
            text = 'Surprise me: today’s background is %s. Tomorrow brings another.' % BG_NAMES.get(now_bg, now_bg)
        else:
            text = 'Your background is used for your desktop and lock screen. Click one to use it.'
        bg_note.set_text(text)
        # 4.2: options, and a note while a pick is just for a while.
        temp = temp_background()
        fit_choice.set_active_id(setting('WallpaperFit'))
        for c in (pick_for, fit_choice):
            c.set_sensitive(not locked and not bg_locked)
        if temp:
            until = datetime.date.fromisoformat(mine()['TempUntil'])
            after = (BG_NAMES[theme] if theme and on_default_background()
                     else 'Surprise me' if bg == SURPRISE else bg_name(bg).replace('Your picture', 'your picture'))
            what = 'your picture' if is_own(temp) else bg_name(temp)
            temp_text.set_text(("You're using %s just for today. Tomorrow it goes back to %s." % (what, after))
                               if until <= today() else
                               ("You're using %s until %s. Then it goes back to %s."
                                % (what, until.strftime('%A, %B %-d'), after)))
        temp_box.set_visible(bool(temp))
        org_bg = org('Background')
        for bid, (btn, cap) in tiles.items():
            chosen = seasonal_on if bid == '__season' else (bid == (temp or bg) and not seasonal_on)
            for w in (btn, cap):
                (w.get_style_context().add_class if chosen else w.get_style_context().remove_class)('chosen')
            if bid != '__season':
                cap.set_text(bg_name(bid) + ('\n' + CAPTIONS[bid] if bid in CAPTIONS else ' (default)' if bid == org_bg else ''))
                # 4.3: only what's out on their release channel (and the organization's default).
                cell = cells.get(bid)
                if cell is not None and cell.get_parent() is not None:
                    cell.get_parent().set_visible(released(bid) or bid == org_bg)
            btn.set_sensitive(not locked and not bg_locked)
        # 6.0.5: each theme's section once one of its backgrounds is out on their channel; 5.9.0: their own pictures on
        # a computer of their own.
        for cid, (cat_box, cat_note) in cat_boxes.items():
            out = [b for b, _ in BACKGROUNDS if CATEGORY_OF.get(b, 'defaults') == cid and (released(b) or b == org_bg)]
            cat_box.set_visible(bool(out) or cid == CATEGORY_OF.get(SURPRISE))
            soon = [bg_name(b) for b in out if b not in VIDEO_HASHES and b not in CHANNEL_ONLY]
            only = [bg_name(b) for b in out if b in CHANNEL_ONLY]
            cat_note.set_text(('For our beta testers. %s plays the TLA Classic intro video.' % ' and '.join(only) if only else '')
                              if not soon else
                              '%s: their own intro videos are coming soon. Until then, they play the TLA Classic video.' % ' and '.join(soon)
                              if len(soon) > 1 else
                              '%s: its own intro video is coming soon. Until then, it plays the TLA Classic video.' % soon[0])
            cat_note.set_visible(bool(cat_note.get_text()))
        own_ok = own_pictures_allowed()
        if own_ok:
            own_box.set_no_show_all(False)
            own_box.show_all()
            sync_own_tiles()             # (after show_all: it hides "Add a picture" when there are as many as can be)
            own_msg.set_visible(bool(own_msg.get_text()))
        else:
            own_box.hide()
        for oid, (obtn, ocap, orm) in own_cells.items():
            chosen = oid == (temp or bg) and not seasonal_on
            for w in (obtn, ocap):
                (w.get_style_context().add_class if chosen else w.get_style_context().remove_class)('chosen')
            obtn.set_sensitive(not locked and not bg_locked)
            orm.set_sensitive(not locked and not bg_locked)
        add_btn.set_sensitive(not locked and not bg_locked)
        ch = channel()
        for cid, r in chan_radios.items():
            r.set_active(cid == ch)
            r.set_sensitive(not locked)
        st_rel, ex_rel = channel_release('stable'), channel_release('experimental')
        newer = vkey(ex_rel) > vkey(st_rel)
        if ch == 'experimental':
            chan_status.set_text("You're on Experimental: version %s.%s" % (shown_release(), (
                ' Stable is on version %s.' % st_rel) if newer else ' Right now it has the same as Stable.'))
        else:
            chan_status.set_text("You're on Stable: version %s.%s" % (shown_release(), (
                ' Experimental has version %s to try.' % ex_rel) if newer else ''))
        version_label.set_text('Version %s · %s' % (shown_release(), dict(CHANNELS)[ch]))
        upd_wrap.set_no_show_all(not released('checkupdates'))     # (5.8.0)
        if released('checkupdates'):
            upd_wrap.show_all()
        else:
            upd_wrap.hide()
        help_note.set_markup(help_markup % (GLib.markup_escape_text(helpdesk_link()), HELPDESK))
        report_btn.set_visible(released('report'))
        # 5.0
        care_btn.set_visible(released('care'))
        help_btns.set_visible(released('report') or released('care'))
        opt_cols['Light or dark'].get_parent().set_visible(released('lightdark'))
        light_dark.set_active_id(setting('LightDark'))
        light_dark.set_sensitive(not locked and not bg_locked)
        update_tiles()
        calls_box.set_visible(released('calls'))
        calls_row_wrap.set_visible(released('calls'))
        reminders_wrap.set_visible(released('care'))
        reminders.set_visible(released('care'))
        reminders.set_active(setting('CareReminders') == 1)
        reminders.set_sensitive(not locked)
        extras.set_visible(released('calls') or released('care'))
        tour_link.set_visible(released('tour'))
        # (whatever the release channel: it's for whoever sets the computer up)
        unbox_box.set_visible(installed_for_everyone() and
                              (unbox_info().get('state') == 'ready' or bool(ui.get('unbox_at'))))
        unbox_btn.set_sensitive(not ui.get('unbox_at'))
        unbox_btn.set_label('Shutting down…' if ui.get('unbox_at') else 'Prepare for initial unboxing')
        reset.set_visible(not locked and any(k not in ('PreferredName', 'Greeting') for k in mine()))
        play_btn.set_sensitive(os.path.exists(video_file()))
        play_quiet.set_sensitive(os.path.exists(video_file()))
        ui['loading'] = False

    def change(name, value):
        if ui['loading'] or not users_can_change() or signed_out():
            return
        save(name, value)
        refresh()

    def write_temp(bg_id=None, until=None):
        """Sets (or with no arguments, forgets) a background picked for a while (4.2)."""
        m = mine()
        m.pop('TempBackground', None)
        m.pop('TempUntil', None)
        if bg_id:
            m.update(TempBackground=bg_id, TempUntil=until)
        write_json(os.path.join(config_dir(), 'settings.json'), m)

    def on_background(bg_id):
        if not users_can_change() or signed_out() or background_locked():
            return
        how = pick_for.get_active_id() or 'Always'
        if how != 'Always' and bg_id != SURPRISE:
            # Just for today, or a week; then what was there before comes back.
            write_temp(bg_id, (today() + datetime.timedelta(days=6 if how == 'Week' else 0)).isoformat())
        else:
            save('Background', bg_id)
            write_temp()
        apply_background()
        refresh()

    def sync_own_tiles():
        """5.9.0: keeps the tiles in step with their pictures folder."""
        want = own_pictures()
        for oid in [o for o in own_cells if o not in want]:
            child = own_cells.pop(oid)[0].get_ancestor(Gtk.FlowBoxChild)
            if child is not None:
                child.destroy()
            tile_imgs.pop(oid, None)
        for oid in want:
            if oid in own_cells:
                continue
            btn = Gtk.Button()
            btn.set_relief(Gtk.ReliefStyle.NONE)
            btn.get_style_context().add_class('tile')
            pb = tile_picture(oid, ui['look'])
            if pb:
                tile_imgs[oid] = Gtk.Image.new_from_pixbuf(pb)
                btn.add(tile_imgs[oid])
            else:
                btn.add(Gtk.Label(label='Your picture'))
            btn.set_tooltip_text('Your picture')
            btn.connect('clicked', lambda _b, i=oid: on_background(i))
            ov = Gtk.Overlay(halign=Gtk.Align.CENTER, valign=Gtk.Align.START)
            ov.add(btn)
            rm = Gtk.Button.new_from_icon_name('window-close-symbolic', Gtk.IconSize.BUTTON)
            rm.get_style_context().add_class('remove')
            rm.set_halign(Gtk.Align.END)
            rm.set_valign(Gtk.Align.START)
            rm.set_margin_end(10)
            rm.set_margin_top(10)
            rm.set_tooltip_text('Remove this picture')
            rm.connect('clicked', lambda _b, i=oid: on_own_remove(i))
            ov.add_overlay(rm)
            cap = Gtk.Label(label='Your picture')
            cap.get_style_context().add_class('tile-name')
            cell = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
            cell.pack_start(ov, False, False, 0)
            cell.pack_start(cap, False, False, 0)
            own_grid.insert(cell, len(own_cells))      # (before "Add a picture")
            cell.show_all()
            own_cells[oid] = (btn, cap, rm)
        add_cell.get_parent().set_visible(len(want) < OWN_MAX)

    def on_own_add(*_):
        if not own_pictures_allowed() or signed_out() or background_locked():
            return
        own_msg.set_text('')
        if len(own_pictures()) >= OWN_MAX:
            own_msg.set_text('You can have up to %d pictures. Remove one to add another.' % OWN_MAX)
            refresh()
            return
        d = Gtk.FileChooserNative.new('Add a picture', win, Gtk.FileChooserAction.OPEN, 'Add', 'Cancel')
        f = Gtk.FileFilter()
        f.set_name('Pictures')
        f.add_pixbuf_formats()
        d.add_filter(f)
        pics = GLib.get_user_special_dir(GLib.UserDirectory.DIRECTORY_PICTURES)
        if pics and os.path.isdir(pics):
            d.set_current_folder(pics)
        r, src = d.run(), d.get_filename()
        d.destroy()
        if r != Gtk.ResponseType.ACCEPT or not src:
            return
        add_btn.set_sensitive(False)
        own_msg.set_text('Adding your picture…')
        own_msg.show()

        def added(res):
            bg_id, err = res or ('', "That picture couldn't be used. Try a JPEG or PNG picture.")
            own_msg.set_text(err)
            if bg_id:
                sync_own_tiles()
                on_background(bg_id)       # (and "Use my pick" decides for how long, as for the others)
            else:
                refresh()
        in_background(lambda: own_add(src), added)

    def on_own_remove(bg_id):
        if not own_pictures_allowed() or signed_out():
            return
        if not confirm(win, 'Remove this picture from TLA BootPaper?',
                       'The picture you added it from stays where it is.', 'Remove'):
            return
        own_msg.set_text('')
        own_remove(bg_id)
        sync_own_tiles()
        apply_background(if_needed=True)
        refresh()

    add_btn.connect('clicked', on_own_add)

    def on_fit(c):
        if ui['loading'] or not c.get_active_id() or not users_can_change():
            return
        save('WallpaperFit', c.get_active_id())
        apply_background()
        refresh()

    def on_temp_end(*_):
        write_temp()
        apply_background()
        refresh()
        return True

    def on_seasonal():
        """Back to the seasonal theme: forget the background they picked (they're on the default again)."""
        if not users_can_change() or background_locked():
            return
        s = mine()
        for k in ('Background', 'TempBackground', 'TempUntil'):
            s.pop(k, None)
        write_json(os.path.join(config_dir(), 'settings.json'), s)
        apply_background()
        refresh()

    def on_reset(*_):
        # Back to the organization's settings, but their name for the greeting stays (5.6.0: and whether it's on).
        keep = {k: v for k, v in mine().items() if k in ('PreferredName', 'Greeting') and valid(k, v)}
        write_json(os.path.join(config_dir(), 'settings.json'), keep)
        apply_background(if_needed=True)
        refresh()
        return True

    def on_days(*_):
        change('QuietDays', ','.join(d for d in DAYS if day_buttons[d].get_active()))

    def typed_name():
        return ' '.join(name_entry.get_text().split())[:NAME_MAX]

    def on_name(*_):
        if ui['loading']:
            return
        name_status.set_text('')
        name_save.set_sensitive(users_can_change() and not signed_out() and typed_name() != setting('PreferredName'))

    def save_name(*_):
        if not users_can_change() or signed_out():
            return
        name = typed_name()
        if not valid('PreferredName', name):
            return
        save('PreferredName', name)
        set_state(NameAsked=1)          # (no need to ask at login now)
        name_entry.set_text(name)
        name_status.set_markup('<span foreground="#2E7D32">%s</span>' % GLib.markup_escape_text(
            'Saved ✓  Your video will say: %s' % greeting() if name else 'Saved ✓  No greeting.'))
        name_save.set_sensitive(False)

    enabled.connect('toggled', lambda b: change('Enabled', int(b.get_active())))
    sound.connect('toggled', lambda b: change('Sound', int(b.get_active())))
    greet_on.connect('toggled', lambda b: (name_status.set_text(''), change('Greeting', int(b.get_active()))))
    skip.connect('toggled', lambda b: change('AllowSkip', int(b.get_active())))
    quiet.connect('changed', lambda c: c.get_active_id() and change('QuietMode', c.get_active_id()))
    q_start.connect('changed', lambda c: c.get_active_id() and change('QuietStart', c.get_active_id()))
    q_end.connect('changed', lambda c: c.get_active_id() and change('QuietEnd', c.get_active_id()))
    for b in day_buttons.values():
        b.connect('toggled', on_days)
    name_entry.connect('changed', on_name)
    name_entry.connect('activate', save_name)
    name_save.connect('clicked', save_name)
    win.connect('delete-event', lambda *_: (name_save.get_sensitive() and save_name(), False)[1])
    video.connect('changed', lambda c: c.get_active_id() and change('Video', c.get_active_id()))

    def on_channel(cid):
        if ui['loading'] or not users_can_change():
            return
        save('Channel', cid)
        apply_background(if_needed=True)     # (what's showing may change with it)
        refresh()
    for cid, r in chan_radios.items():
        r.connect('toggled', lambda b, c=cid: b.get_active() and on_channel(c))
    for pid, r in radios.items():
        r.connect('toggled', lambda b, p=pid: b.get_active() and change('PlayWhen', p))
    # 5.0
    def update_tiles():
        """The tiles show the look (light or dark) the backgrounds have now."""
        look = style()
        if look == ui['look']:
            return
        ui['look'] = look
        for bid, img in tile_imgs.items():
            pb = tile_picture(theme_now if bid == '__season' else bid, look)
            if pb:
                img.set_from_pixbuf(pb)

    def follow_style():
        # (every few seconds while the window is open: Settings > Appearance may change it)
        if setting('LightDark') == 'Auto':
            update_tiles()
        return True
    GLib.timeout_add_seconds(3, follow_style)

    def on_light_dark(c):
        if ui['loading'] or not c.get_active_id() or not users_can_change():
            return
        save('LightDark', c.get_active_id())
        apply_background()
        refresh()

    def on_calls_open(*_):
        calls_open.set_sensitive(False)
        calls_note.set_text('Getting the pictures ready…')

        def opened(folder):
            calls_open.set_sensitive(True)
            calls_note.set_text('Opened: the pictures are in your Pictures folder, under TLA backgrounds.'
                                if folder and open_folder(win, folder) else
                                "Couldn't open the folder. The pictures are in your Pictures folder, under TLA backgrounds.")
        in_background(call_pictures_folder, opened)

    def on_unbox(*_):
        """Prepare for initial unboxing: confirm, then the guard (as root) marks the computer and shuts it down."""
        if not confirm(win, 'Prepare this computer for unboxing?',
                       'It shuts down straight away, so save your work first. The next time it starts, whoever logs in '
                       'gets the TLA Classic intro and the Welcome to TLA tour.\n\nThis can only be done once on this '
                       'computer.', 'Prepare and shut down'):
            return
        if unbox_info().get('state') != 'ready':
            tell(win, 'Prepare for initial unboxing', 'This computer has already been prepared for unboxing.')
            refresh()
            return
        at = care_request('unbox')
        if not at:
            tell(win, 'Prepare for initial unboxing', 'Couldn’t prepare the computer. Try again in a moment.')
            return
        ui['unbox_at'] = at
        refresh()
        end = time.time() + 75          # (the guard answers within about 20 seconds)

        def poll():
            r = care_result('unbox', at)
            if r == 'Shutting down.' or (r is None and time.time() < end):
                return True
            ui['unbox_at'] = None
            tell(win, 'Prepare for initial unboxing', r or 'The computer didn’t answer. Try again in a moment.')
            refresh()
            return False
        GLib.timeout_add(1500, poll)

    # ---- 5.8.0: Check for updates ------------------------------------------------------------------------------
    # 6.1.0: the version installed now (VERSION, which an update replaces), a button that opens it, and following an
    # update until it's in.
    def installed_release():
        try:
            with open(os.path.join(APP_DIR, 'VERSION')) as f:
                return f.read().strip() or RELEASE
        except OSError:
            return RELEASE

    def on_restart(*_):
        subprocess.Popen(['/usr/bin/python3', os.path.abspath(__file__), 'app'], start_new_session=True,
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        Gtk.main_quit()
    upd_restart.connect('clicked', on_restart)

    def follow_update(text):
        m = re.match(r'Version ([0-9.]+) is out', text or '')
        if not m:
            upd_btn.set_sensitive(True)
            return
        version, end = m.group(1), time.time() + 20 * 60
        upd_bar.show()

        def tick():
            v = installed_release()
            if vkey(v) >= vkey(version):
                upd_text.set_text('Updated to version %s at %s. Restart TLA BootPaper to use it.'
                                  % (v, datetime.datetime.now().strftime('%-I:%M %p')))
                upd_bar.hide(); upd_restart.show(); upd_btn.set_sensitive(True)
                return False
            if time.time() > end:
                upd_text.set_text('Version %s is still installing. It finishes by itself; check again in a few minutes.' % version)
                upd_bar.hide(); upd_btn.set_sensitive(True)
                return False
            upd_text.set_text('Installing version %s… This takes a few minutes. You can keep using your computer.' % version)
            upd_bar.pulse()
            return True
        GLib.timeout_add(500, tick)

    def stale_check():
        """6.1.0: a newer version installed while this window was open (by itself, or from another window)."""
        if upd_btn.get_sensitive() and not upd_restart.get_visible() and upd_wrap.get_visible():
            v = installed_release()
            if v != RELEASE and vkey(v) > vkey(RELEASE):
                upd_text.set_text('TLA BootPaper was updated to version %s. Restart it to use the new version.' % v)
                upd_restart.show()
        return True
    GLib.timeout_add_seconds(10, stale_check)

    def on_check_updates(*_):
        """The guard (as root) checks GitHub and starts the update; a copy installed for one person checks itself."""
        upd_btn.set_sensitive(False)
        upd_restart.hide(); upd_bar.hide()
        upd_text.set_text('Checking… This can take up to a minute.')
        at = care_request('update')
        if not at:              # (installed for one person: no guard to ask)
            def job():
                text = check_update_now()
                GLib.idle_add(lambda: (upd_text.set_text(text), follow_update(text), False)[2])
            threading.Thread(target=job, daemon=True).start()
            return
        end = time.time() + 90          # (the guard answers within about 20 seconds)

        def poll():
            r = care_result('update', at)
            if r is None and time.time() < end:
                return True
            upd_text.set_text(r or 'The check is taking longer than usual. Try again in a few minutes.')
            follow_update(r)      # (6.1.0)
            return False
        GLib.timeout_add(1500, poll)
    upd_btn.connect('clicked', on_check_updates)

    # ---- 5.7.0: signing in -------------------------------------------------------------------------------------
    def on_signin(*_):
        lst = ui.get('signin_listener')
        if lst:                                   # (the button says Cancel meanwhile)
            lst.close()
            ui['signin_listener'] = None
            refresh()
            return
        try:
            lst = SignInListener(signin_came_back)
        except OSError as e:
            ui['signin_msg'] = 'Couldn’t start signing in (%s). Try again.' % e
            refresh()
            return
        pend = signin_begin(lst.port)
        ui.update(signin_listener=lst, signin_pend=pend, signin_msg='')
        GLib.timeout_add(200, lambda: ui.get('signin_listener') is lst and lst.poll())
        try:
            Gtk.show_uri_on_window(win, pend['url'], Gdk.CURRENT_TIME)
        except Exception:
            subprocess.Popen(['xdg-open', pend['url']], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        refresh()

    def signin_came_back(q):
        ui['signin_listener'] = None
        ok, msg = signin_finish(ui.get('signin_pend') or {}, q)
        ui['signin_msg'] = '' if ok else msg
        if ok and signed_out():                   # (checked; the guard is fetching the key it was signed with)
            ui['signin_wait'] = time.time() + 75
            GLib.timeout_add(2000, signin_wait)
        elif ok:
            apply_background(if_needed=True)
        win.present()
        refresh()

    def signin_wait():
        if not signed_out() or time.time() > (ui.get('signin_wait') or 0) or signin_now(fresh=True)['state'] != 'out':
            if signed_out():
                ui['signin_msg'] = 'Couldn’t finish signing in. Try again in a minute.'
            ui['signin_wait'] = None
            apply_background(if_needed=True)
            refresh()
            return False
        return True

    def on_signout(*_):
        if confirm(win, 'Sign out of TLA BootPaper?', 'Your choices stay saved. Until you sign in again, you’ll see '
                   'TLA Classic.', 'Sign out'):
            signin_forget()
            log('Signed out.')
            apply_background(if_needed=True)
            refresh()
        return True

    signin_btn.connect('clicked', on_signin)
    signout_btn.connect('activate-link', on_signout)
    light_dark.connect('changed', on_light_dark)
    reminders.connect('toggled', lambda b: change('CareReminders', int(b.get_active())))
    calls_open.connect('clicked', on_calls_open)
    unbox_btn.connect('clicked', on_unbox)
    tour_link.connect('activate-link', lambda *_: (tour_window(), True)[1])

    reset.connect('activate-link', on_reset)
    news.connect('activate-link', lambda *_: (whats_new_window(win), True)[1])
    play_btn.connect('clicked', lambda *_: (play_video(force=True), refresh()))
    play_quiet.connect('activate-link', lambda *_: (play_video(force=True, mute_it=True), refresh(), True)[2])
    fit_choice.connect('changed', on_fit)
    temp_end.connect('activate-link', on_temp_end)
    close.connect('clicked', lambda *_: win.destroy())
    win.connect('key-press-event', lambda w, e: e.keyval == Gdk.KEY_Escape and (w.destroy() or True))

    refresh()
    win.show_all()
    refresh()   # (show_all shows the hidden bits again)
    if sign_in and signed_out() or sign_in and signin_now()['state'] in ('renew', 'grace'):
        GLib.idle_add(lambda: (on_signin(), False)[1])     # (5.7.0: "Sign in" in a reminder)
    if os.environ.get('TLA_SNAPSHOT'):   # developer check: picture of the window, then quit
        to = os.environ.get('TLA_SCROLL', '')          # (end, or how far down)
        if to:
            GLib.timeout_add(900, lambda: (scroll.get_vadjustment().set_value(
                scroll.get_vadjustment().get_upper() if to == 'end' else int(to)), False)[1])

        def snap():
            win.get_window().get_screen()
            os.system('xwd -root -silent | convert xwd:- "%s"' % os.environ['TLA_SNAPSHOT'])
            Gtk.main_quit()
        GLib.timeout_add(1500, snap)
    Gtk.main()


def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else 'app'
    if cmd == 'app':
        run_app(sign_in='--signin' in sys.argv)      # (5.7.0: --signin, from a reminder: start signing in)
    elif cmd == 'whatsnew':
        run_app(whats_new_only=True)
    elif cmd == 'login':
        login()
    elif cmd == 'play':          # play [<video id> [mute]]  (4.2)
        play_video(force=True, vid=(sys.argv[2] if len(sys.argv) > 2 and sys.argv[2] != '-' else None),
                   mute_it=len(sys.argv) > 3 and sys.argv[3] == 'mute')
    elif cmd == 'apply':
        apply_background(if_needed='--if-needed' in sys.argv)
    elif cmd == 'guard':
        guard()
    elif cmd == 'update':
        self_update(force=True)
    elif cmd == 'gst-play':
        sys.exit(gst_play(sys.argv[2], sys.argv[3] == '1', sys.argv[4] == '1', sys.argv[5] if len(sys.argv) > 5 else ''))
    elif cmd == 'sync-videos':
        sys.exit(1 if sync_videos() else 0)
    elif cmd == 'ask-name':
        run_app(ask_name_only=True)
    elif cmd == 'report':        # 4.3
        run_app(report_only=True)
    elif cmd == 'details':
        print('\n'.join('%s: %s' % x for x in device_details()))
    elif cmd == 'announcement':
        sync_announcement()
        print(announcement() or '(no announcement)')
    # 5.0
    elif cmd == 'care':
        run_app(care_only=True)
    elif cmd == 'tour':
        run_app(tour_only=True)
    elif cmd == 'session-tick':
        session_tick()
    elif cmd == 'nudge':
        nudge()
    # 5.7.0
    elif cmd == 'signin-remind':
        signin_remind()
    elif cmd == 'signin-status':
        print(json.dumps(signin_now(), indent=1))
    elif cmd == 'care-checks':
        for r in care_checks(quick='--quick' in sys.argv):
            print('\t'.join(r[k] for k in ('id', 'status', 'title', 'detail', 'action', 'action_text')))
    else:
        sys.exit('usage: tla-bootpaper.py app|whatsnew|login|play|apply|guard|sync-videos|update|ask-name|announcement|'
                 'report|details|care|tour|care-checks')


if __name__ == '__main__':
    main()
