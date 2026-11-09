#!/usr/bin/env python3
"""Copies the TLA BootPaper announcement from Intune into this repository (5.8.0), for the computers that read it from
here: Macs and Windows PCs that Intune doesn't manage, and the Linux laptops. Intune-managed Macs and Windows PCs get
it from Intune itself. The announcement is written on the TLA BootPaper staff page, which saves it to the
"TLA Announcement (Mac lock screen)" and "TLA Announcement (Windows lock screen)" Intune policies; this reads the Mac
one (or the Windows one, if there's no Mac one) and writes mac/, linux/ and windows/announcement.txt.

Runs in the "announcement" GitHub Actions job (.github/workflows/announcement.yml). It signs in to Microsoft Graph as
the "TLA BootPaper Announcement Copy" app with GitHub's own sign-in token for this repository's main branch (a
federated credential on that app), so there's no password or secret anywhere. The app may only read Intune's
device configuration (DeviceManagementConfiguration.ReadWrite.All since 7.5: it also clears an announcement whose end
date has passed. The staff page keeps that date in the Mac policy's description as "Announcement ends: YYYY-MM-DD").

Prints what it did. If Intune can't be read, it changes nothing and says why in a warning on the job (the job still
passes, so a pause on Microsoft's side doesn't send a failure email every 10 minutes)."""
import json
import os
import re
import sys
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime
from zoneinfo import ZoneInfo

TENANT = 'schoolathome.ca'
CLIENT_ID = os.environ.get('ANNOUNCE_CLIENT_ID', '')
GRAPH = 'https://graph.microsoft.com/beta'
MAC_POLICY = 'TLA Announcement (Mac lock screen)'
WIN_POLICY = 'TLA Announcement (Windows lock screen)'
IPAD_POLICY = 'TLA Announcement (iPad lock screen)'
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'TLA-BootPaper')
HEADER = """# TLA BootPaper announcement, for {who}.
# Copied here from Intune about every 10 minutes (the "announcement" job in this repository). To change it, use the
# TLA BootPaper staff page: a change made here is replaced. An empty line below means no announcement.
# Lines starting with # are notes like these and are never shown. Remember this file is public: anyone can read it.
"""
WHO = {'mac': "Macs that Intune doesn't manage", 'windows': "Windows PCs that Intune doesn't manage",
       'linux': 'the Linux laptops'}


def call(url, data=None, headers=None):
    req = urllib.request.Request(url, data=data, headers=headers or {})
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.load(r)


def graph_token():
    gh = call(os.environ['ACTIONS_ID_TOKEN_REQUEST_URL'] + '&audience=' + urllib.parse.quote('api://AzureADTokenExchange'),
              headers={'Authorization': 'Bearer ' + os.environ['ACTIONS_ID_TOKEN_REQUEST_TOKEN']})['value']
    body = urllib.parse.urlencode({
        'client_id': CLIENT_ID, 'grant_type': 'client_credentials', 'scope': 'https://graph.microsoft.com/.default',
        'client_assertion_type': 'urn:ietf:params:oauth:client-assertion-type:jwt-bearer', 'client_assertion': gh,
    }).encode()
    return call(f'https://login.microsoftonline.com/{TENANT}/oauth2/v2.0/token', data=body)['access_token']


def all_pages(path, auth):
    out, url = [], GRAPH + path
    while url:
        j = call(url, headers=auth)
        out += j.get('value', [])
        url = j.get('@odata.nextLink')
    return out


def find_text(node):
    """The first setting value (deep) whose definition is the login window text."""
    if isinstance(node, dict):
        if re.search('loginwindowtext', node.get('settingDefinitionId') or '', re.I) and node.get('simpleSettingValue'):
            return node['simpleSettingValue'].get('value') or ''
        node = list(node.values())
    if isinstance(node, list):
        for v in node:
            r = find_text(v)
            if r is not None:
                return r
    return None


def announcement(auth):
    mac = next((p for p in all_pages('/deviceManagement/configurationPolicies?$select=id,name&$top=100', auth)
                if p.get('name') == MAC_POLICY), None)
    if mac:
        full = call(f"{GRAPH}/deviceManagement/configurationPolicies/{mac['id']}?$expand=settings", headers=auth)
        text = find_text(full.get('settings'))
        if text is not None:
            return text, 'Mac policy'
    win = next((p for p in all_pages('/deviceManagement/groupPolicyConfigurations?$select=id,displayName', auth)
                if p.get('displayName') == WIN_POLICY), None)
    if win:
        for d in all_pages(f"/deviceManagement/groupPolicyConfigurations/{win['id']}/definitionValues"
                           '?$expand=presentationValues', auth):
            if not d.get('enabled'):
                return '', 'Windows policy (switched off)'
            for p in d.get('presentationValues') or []:
                if 'values' in p:
                    return ' '.join(p['values'] or []), 'Windows policy'
                if 'value' in p and isinstance(p['value'], str):
                    return p['value'], 'Windows policy'
    raise RuntimeError("neither announcement policy has a text setting")


def send(method, path, auth, body):
    req = urllib.request.Request(GRAPH + path, data=json.dumps(body).encode(), method=method,
                                 headers=dict(auth, **{'Content-Type': 'application/json'}))
    with urllib.request.urlopen(req, timeout=30) as r:
        r.read()


def clear_if_ended(auth):
    """7.5: if the staff page gave the announcement an end date and that day is over (Vancouver), clear it in all three
    policies, the way the staff page's "No announcement" does. Returns True if it cleared it."""
    mac = next((p for p in all_pages('/deviceManagement/configurationPolicies?$select=id,name&$top=100', auth)
                if p.get('name') == MAC_POLICY), None)
    if not mac:
        return False
    full = call(f"{GRAPH}/deviceManagement/configurationPolicies/{mac['id']}?$expand=settings", headers=auth)
    m = re.search(r'Announcement ends: (\d{4}-\d{2}-\d{2})', full.get('description') or '')
    today = datetime.now(ZoneInfo('America/Vancouver')).strftime('%Y-%m-%d')
    if not m or m.group(1) >= today:
        return False
    print('The announcement ended on %s: clearing it.' % m.group(1))

    def blank(node):                  # the login window text becomes a single space (Intune won't take empty)
        if isinstance(node, dict):
            if re.search('loginwindowtext', node.get('settingDefinitionId') or '', re.I) and node.get('simpleSettingValue'):
                node['simpleSettingValue']['value'] = ' '
            for v in node.values():
                blank(v)
        elif isinstance(node, list):
            for v in node:
                blank(v)
    blank(full.get('settings'))
    send('PUT', f"/deviceManagement/configurationPolicies/{mac['id']}", auth, {
        'name': full['name'], 'platforms': full.get('platforms'), 'technologies': full.get('technologies'),
        'description': re.sub(r'\n?Announcement ends: .*', '', full.get('description') or '').strip(),
        'roleScopeTagIds': full.get('roleScopeTagIds'), 'templateReference': full.get('templateReference'),
        'settings': [{'@odata.type': '#microsoft.graph.deviceManagementConfigurationSetting',
                      'settingInstance': x['settingInstance']} for x in full.get('settings') or []]})
    win = next((p for p in all_pages('/deviceManagement/groupPolicyConfigurations?$select=id,displayName', auth)
                if p.get('displayName') == WIN_POLICY), None)
    if win:
        for d in all_pages(f"/deviceManagement/groupPolicyConfigurations/{win['id']}/definitionValues", auth):
            if d.get('enabled'):
                send('PATCH', f"/deviceManagement/groupPolicyConfigurations/{win['id']}/definitionValues/{d['id']}", auth,
                     {'@odata.type': '#microsoft.graph.groupPolicyDefinitionValue', 'enabled': False})
    ipad = next((p for p in all_pages('/deviceManagement/deviceConfigurations?$select=id,displayName', auth)
                 if p.get('displayName') == IPAD_POLICY), None)
    if ipad:
        send('PATCH', f"/deviceManagement/deviceConfigurations/{ipad['id']}", auth,
             {'@odata.type': '#microsoft.graph.iosDeviceFeaturesConfiguration', 'lockScreenFootnote': None})
    return True


def clean(text):
    text = re.sub(r'[\x00-\x1f\x7f]+', ' ', text or '')
    return re.sub(r'\s+', ' ', text).strip()[:300].strip()


def main():
    if not CLIENT_ID:
        print('ANNOUNCE_CLIENT_ID is not set.')
        return 1
    try:
        auth = {'Authorization': 'Bearer ' + graph_token()}
        try:
            clear_if_ended(auth)
        except urllib.error.HTTPError as e:
            if e.code == 403:
                print('::warning::The announcement has ended, but this app may not change Intune yet: give "TLA BootPaper '
                      'Announcement Copy" DeviceManagementConfiguration.ReadWrite.All (with admin consent) in Entra.')
            else:
                raise
        text, source = announcement(auth)
    except Exception as e:
        detail = ''
        if isinstance(e, urllib.error.HTTPError):
            try:
                detail = ' ' + e.read().decode('utf-8', 'replace')[:400]
            except Exception:
                pass
        print("::warning::Couldn't read the announcement from Intune, so nothing changed: %s%s" % (e, detail))
        return 0
    text = clean(text)
    print('From the %s: %s' % (source, text or '(no announcement)'))
    for platform, who in WHO.items():
        path = os.path.join(ROOT, platform, 'announcement.txt')
        content = HEADER.format(who=who) + text + '\n'
        try:
            same = open(path, encoding='utf-8').read() == content
        except OSError:
            same = False
        if not same:
            with open(path, 'w', encoding='utf-8') as f:
                f.write(content)
            print('Updated %s/announcement.txt' % platform)
    return 0


if __name__ == '__main__':
    sys.exit(main())
