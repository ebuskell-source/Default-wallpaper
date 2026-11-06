; tla-bootpaper.nsi (5.4) - the TLA BootPaper installer for Windows computers that Intune doesn't manage.
; It runs the same install-video.ps1 Intune runs, then adds TLA BootPaper to Settings > Apps > Installed apps
; (with an uninstaller). Those computers keep themselves up to date (update.ps1: "TLA BootPaper Updates" task),
; by running a newer copy of this installer with /S (silent).
;   makensis -DVERSION=5.4 -DSRC=<folder with install-video.ps1 and the rest> -DOUT=<setup .exe> tla-bootpaper.nsi

Unicode true
SetCompressor /SOLID lzma
!include "MUI2.nsh"
!include "x64.nsh"
!include "LogicLib.nsh"
!include "WinVer.nsh"

!define ARP "Software\Microsoft\Windows\CurrentVersion\Uninstall\TLA BootPaper"
Name "TLA BootPaper ${VERSION}"
OutFile "${OUT}"
RequestExecutionLevel admin
ShowInstDetails show
ShowUninstDetails show
BrandingText "Traditional Learning Academy"
VIProductVersion "${VIVERSION}"   ; (four numbers: 5.4.5.0)
VIAddVersionKey "ProductName" "TLA BootPaper"
VIAddVersionKey "CompanyName" "Traditional Learning Academy"
VIAddVersionKey "FileDescription" "TLA BootPaper Setup"
VIAddVersionKey "FileVersion" "${VERSION}"
VIAddVersionKey "ProductVersion" "${VERSION}"
VIAddVersionKey "LegalCopyright" "Traditional Learning Academy"

!define MUI_ICON "${SRC}/welcome-video.ico"
!define MUI_UNICON "${SRC}/welcome-video.ico"
!define MUI_WELCOMEPAGE_TITLE "TLA BootPaper ${VERSION}"
!define MUI_WELCOMEPAGE_TEXT "This sets up TLA BootPaper on this computer: the TLA intro video when someone signs in, the TLA desktop and lock screen backgrounds, TLA Care, and the Welcome to TLA tour.$\r$\n$\r$\nIt downloads the intro videos while it installs, which can take a few minutes. Afterwards it keeps itself up to date.$\r$\n$\r$\nComputers connected to TLA through Intune already get TLA BootPaper and don't need this."
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_INSTFILES
!define MUI_FINISHPAGE_TITLE "TLA BootPaper is set up"
!define MUI_FINISHPAGE_TEXT "The intro video plays the next time someone signs in.$\r$\n$\r$\nTo pick a video and background, open TLA BootPaper from the Start menu."
!insertmacro MUI_PAGE_FINISH
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_LANGUAGE "English"

Var PS   ; 64-bit PowerShell on 64-bit Windows (this installer is 32-bit), so the registry and folders are the real ones

!macro FindPowerShell
  ${If} ${RunningX64}
    SetRegView 64
    StrCpy $PS "$WINDIR\Sysnative\WindowsPowerShell\v1.0\powershell.exe"
  ${Else}
    StrCpy $PS "$SYSDIR\WindowsPowerShell\v1.0\powershell.exe"
  ${EndIf}
  SetShellVarContext all
!macroend

Function .onInit
  ${IfNot} ${AtLeastWin10}
    MessageBox MB_ICONSTOP "TLA BootPaper needs Windows 10 or later." /SD IDOK
    SetErrorLevel 3
    Abort
  ${EndIf}
  !insertmacro FindPowerShell
  StrCpy $INSTDIR "$APPDATA\WelcomeVideo"   ; (C:\ProgramData\WelcomeVideo, where install-video.ps1 puts it)
FunctionEnd

Function un.onInit
  !insertmacro FindPowerShell
FunctionEnd

Section "TLA BootPaper"
  InitPluginsDir
  SetOutPath "$PLUGINSDIR\src"
  File /r "${SRC}/*.*"
  DetailPrint "Installing TLA BootPaper ${VERSION} and downloading the intro videos..."
  nsExec::ExecToLog '"$PS" -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "$PLUGINSDIR\src\install-video.ps1"'
  Pop $0
  SetOutPath "$TEMP"
  ${If} $0 != 0
    DetailPrint "The install didn't finish (error $0)."
    MessageBox MB_ICONSTOP "TLA BootPaper couldn't be installed (error $0). Try again, or email helpdesk@schoolathome.ca." /SD IDOK
    SetErrorLevel 2
    Abort
  ${EndIf}
  ; Settings > Apps > Installed apps, with an uninstaller (Intune keeps track of its own installs)
  WriteUninstaller "$INSTDIR\Uninstall TLA BootPaper.exe"
  WriteRegStr HKLM "${ARP}" "DisplayName" "TLA BootPaper"
  WriteRegStr HKLM "${ARP}" "DisplayVersion" "${VERSION}"
  WriteRegStr HKLM "${ARP}" "Publisher" "Traditional Learning Academy"
  WriteRegStr HKLM "${ARP}" "DisplayIcon" "$INSTDIR\welcome-video.ico"
  WriteRegStr HKLM "${ARP}" "InstallLocation" "$INSTDIR"
  WriteRegStr HKLM "${ARP}" "HelpLink" "mailto:helpdesk@schoolathome.ca"
  WriteRegStr HKLM "${ARP}" "UninstallString" '"$INSTDIR\Uninstall TLA BootPaper.exe"'
  WriteRegStr HKLM "${ARP}" "QuietUninstallString" '"$INSTDIR\Uninstall TLA BootPaper.exe" /S'
  WriteRegDWORD HKLM "${ARP}" "NoModify" 1
  WriteRegDWORD HKLM "${ARP}" "NoRepair" 1
  WriteRegDWORD HKLM "${ARP}" "EstimatedSize" 230000
  DetailPrint "TLA BootPaper ${VERSION} is set up."
SectionEnd

Section "Uninstall"
  InitPluginsDir
  DetailPrint "Removing TLA BootPaper..."
  ${If} ${FileExists} "$INSTDIR\uninstall-video.ps1"
    CopyFiles /SILENT "$INSTDIR\uninstall-video.ps1" "$PLUGINSDIR\uninstall-video.ps1"
    nsExec::ExecToLog '"$PS" -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "$PLUGINSDIR\uninstall-video.ps1"'
    Pop $0
  ${EndIf}
  DeleteRegKey HKLM "${ARP}"
  Delete "$INSTDIR\Uninstall TLA BootPaper.exe"   ; (uninstall-video.ps1 removes the rest)
SectionEnd
