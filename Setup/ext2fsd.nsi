; ext2fsd.nsi
;
; This is a NSIS script to create an install program for the Ext2Fsd project
; developed by Bo Brantén <bosse@accum.se> in 2020 to help beta testing.
;
; To build an installation program follow these steps:
; 1. Install NSIS (Nullsoft Scriptable Install System)
; 2. Compile Ext2Mgr, Ext2Srv and Ext4Fsd.
; 3. Run the command "makensis ext2fsd.nsi"
; This will create an install program called "Ext2Fsd-setup.exe".
; (for compatibility reasons the install program, install direcory and
;  file names are still called Ext2Fsd even if the driver supports the
;  ext2, ext3 and ext4 filesystems)
;
Unicode true
!include "x64.nsh"

Name "Ext2,Ext3,Ext4 filesystem driver"
!define PROJECTNAME "Ext2Fsd"
!define DRIVERNAME "Ext2Fsd"
Icon "..\Ext2Mgr\res\Ext2Mgr.ico"
Caption "${PROJECTNAME} 0.71"
DirText "This is a release of the ${PROJECTNAME} project from Bo Brantén to test the new ext4 features metadata checksums and 64-bit block numbers. You may choose the install directory:"
InstallDir "$PROGRAMFILES\${PROJECTNAME}"
OutFile "${PROJECTNAME}-setup.exe"

; the paths to the binaries when compiled with Visual Studio to support Windows 10.
; (the driver files are automatically signed or testsigned by Visual Studio)
!ifndef MGRPATH_X86
!define MGRPATH_X86 "..\Ext2Mgr\Release\x86"
!endif
!ifndef MGRPATH_X64
!define MGRPATH_X64 "..\Ext2Mgr\Release\x64"
!endif
!ifndef SRVPATH_X86
!define SRVPATH_X86 "..\Ext2Srv\Release\x86"
!endif
!ifndef SRVPATH_X64
!define SRVPATH_X64 "..\Ext2Srv\Release\x64"
!endif
!ifndef SYSPATH_X86
!define SYSPATH_X86 "..\drivers\Release\x86"
!endif
!ifndef SYSPATH_X64
!define SYSPATH_X64 "..\drivers\Release\x64"
!endif
!ifndef MSVPATH_X86
!define MSVPATH_X86 "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Redist\MSVC\14.42.34433\x86\Microsoft.VC143.CRT"
!endif
!ifndef MSVPATH_X64
!define MSVPATH_X64 "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Redist\MSVC\14.42.34433\x64\Microsoft.VC143.CRT"
!endif
!ifndef MFCPATH_X86
!define MFCPATH_X86 "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Redist\MSVC\14.42.34433\x86\Microsoft.VC143.MFC"
!endif
!ifndef MFCPATH_X64
!define MFCPATH_X64 "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Redist\MSVC\14.42.34433\x64\Microsoft.VC143.MFC"
!endif
!define VCDLL_X86 "vcruntime140"
!define VCDLL_X64A "vcruntime140"
!define VCDLL_X64B "vcruntime140_1"
!define MFCDLL "mfc140"

; the paths to the binaries when compiled with an older WDK to support Windows XP - Windows 8.1.
; (remember to sign or testsign the driver files before packing the installation program)
;!define MGRPATH_X86 "..\..\Ext2Fsd-0.69\Setup"
;!define MGRPATH_X64 "..\..\Ext2Fsd-0.69\Setup"
;!define SRVPATH_X86 "..\..\Ext2Fsd-0.69\Setup"
;!define SRVPATH_X64 "..\..\Ext2Fsd-0.69\Setup"
;!define SYSPATH_X86 "..\Ext4Fsd\winxp\fre\i386"
;!define SYSPATH_X64 "..\Ext4Fsd\winnet\fre\amd64"
;!define MSVPATH_X86 "c:\windows\syswow64"
;!define MSVPATH_X64 "c:\windows\syswow64" ; "c:\windows\sysnative"
;!define MFCPATH_X86 "c:\windows\syswow64"
;!define MFCPATH_X64 "c:\windows\syswow64" ; "c:\windows\sysnative"
;!define VCDLL_X86 "msvcrt"
;!define VCDLL_X64 "msvcrt"
;!define MFCDLL "mfc42"
; note that when building the installation program on a 64-bit system
; the 32-bit system dll's will be in the "\windows\syswow64" directory while
; the 64-bit system dll's will be in the "\windows\system32" directory and
; since the installation script compiler itself is a 32-process the
; "\windows\system32" directory is reached through the alias "\windows\sysnative"
; (in this case the app's and dll's is always 32-bit so we get
;  the dll's from the "\windows\syswow64" directory)

RequestExecutionLevel admin

Function .onInit
    SetShellVarContext all
    IfFileExists $WINDIR\SysWOW64\*.* 0 else
        ; 64-bit
        StrCpy $INSTDIR "$PROGRAMFILES64\${PROJECTNAME}"
        Goto endif
    else:
        ; 32-bit
        StrCpy $INSTDIR "$PROGRAMFILES\${PROJECTNAME}"
    endif:
FunctionEnd

Section "Driver"
SetShellVarContext all
ReadRegStr $0 HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${PROJECTNAME}" \
                   "UninstallString"
StrCmp $0 "" check_secureboot
    ; uninstall an old version if any.

check_secureboot:
; Abort if Secure Boot is enabled: test-signed drivers cannot load with Secure Boot active.
ReadRegDWORD $0 HKLM "SYSTEM\CurrentControlSet\Control\SecureBoot\State" "UEFISecureBootEnabled"
IntCmp $0 1 secureboot_on secureboot_off secureboot_off
secureboot_on:
    MessageBox MB_ICONSTOP|MB_OK "Secure Boot is enabled on this system.$\n$\nThis driver uses test-signing and cannot be loaded while Secure Boot is active.$\n$\nPlease disable Secure Boot in your UEFI/BIOS firmware settings, then run this installer again."
    Abort
secureboot_off:

; Inform the user that test-signing mode will be enabled.
MessageBox MB_OKCANCEL|MB_ICONINFORMATION \
    "This installer will:$\n$\n  \x95 Trust the Ext2Fsd test certificate$\n  \x95 Enable Windows Test-Signing mode$\n  \x95 Register the Ext2Fsd driver service$\n$\nA restart is required after installation for the driver to activate.$\n$\nNote: Test-Signing mode shows a watermark on the desktop. It does not weaken general OS security." \
    IDOK ts_notice_ok
    Abort
ts_notice_ok:

install:

SetOutPath $INSTDIR

; select the files.
IfFileExists $WINDIR\SysWOW64\*.* 0 else
    ; 64-bit.
    File "${MSVPATH_X64}\${VCDLL_X64A}.dll"
    File "${MSVPATH_X64}\${VCDLL_X64B}.dll"
    File "${MFCPATH_X64}\${MFCDLL}.dll"
    File "${MGRPATH_X64}\Ext2Mgr.exe"
    File "${SRVPATH_X64}\Ext2Srv.exe"
;    File "${SYSPATH_X64}\${DRIVERNAME}.pdb"
    File "${SYSPATH_X64}\${DRIVERNAME}.sys"
    File "${SYSPATH_X64}\${DRIVERNAME}.inf"
    File "${SYSPATH_X64}\${DRIVERNAME}.cat"
    File "${SYSPATH_X64}\${DRIVERNAME}-TestSign.cer"
    Goto endif
else:
    ; 32-bit.
!ifndef X64_ONLY
    File "${MSVPATH_X86}\${VCDLL_X86}.dll"
    File "${MFCPATH_X86}\${MFCDLL}.dll"
    File "${MGRPATH_X86}\Ext2Mgr.exe"
    File "${SRVPATH_X86}\Ext2Srv.exe"
;    File "${SYSPATH_X86}\${DRIVERNAME}.pdb"
    File "${SYSPATH_X86}\${DRIVERNAME}.sys"
    File "${SYSPATH_X86}\${DRIVERNAME}.inf"
    File "${SYSPATH_X86}\${DRIVERNAME}.cat"
    File "${SYSPATH_X86}\${DRIVERNAME}-TestSign.cer"
!endif
endif:

SetOutPath $INSTDIR\Documents
File "..\ext4fsd\COPYRIGHT.txt"
File "..\ext4fsd\FAQ.txt"
File "..\ext4fsd\notes.txt"
File "..\ext4fsd\readme.txt"

; Install the test certificate into the machine certificate stores.
; certutil.exe is present in both System32 and SysWOW64 on 64-bit Windows.
ExecWait '"$SYSDIR\certutil.exe" -addstore TrustedPublisher "$INSTDIR\${DRIVERNAME}-TestSign.cer"' $0
ExecWait '"$SYSDIR\certutil.exe" -addstore Root "$INSTDIR\${DRIVERNAME}-TestSign.cer"' $0

; Enable test-signing mode (takes effect after the next reboot).
; bcdedit.exe only exists in 64-bit System32, so use sysnative on 64-bit Windows.
IfFileExists $WINDIR\SysWOW64\*.* 0 bcdedit_32bit
    ExecWait '"$WINDIR\sysnative\bcdedit.exe" /set testsigning on' $0
    Goto bcdedit_done
bcdedit_32bit:
    ExecWait '"$SYSDIR\bcdedit.exe" /set testsigning on' $0
bcdedit_done:

; Copy the driver binary to System32\drivers.
; Disable WOW64 filesystem redirection so we write to the real 64-bit System32.
IfFileExists $WINDIR\SysWOW64\*.* 0 copy_sys_32bit
    ${DisableX64FSRedirection}
    CopyFiles /SILENT "$INSTDIR\${DRIVERNAME}.sys" "$WINDIR\System32\drivers\${DRIVERNAME}.sys"
    ${EnableX64FSRedirection}
    Goto copy_sys_done
copy_sys_32bit:
    CopyFiles /SILENT "$INSTDIR\${DRIVERNAME}.sys" "$WINDIR\System32\drivers\${DRIVERNAME}.sys"
copy_sys_done:

; Register the kernel filesystem driver service in the Windows SCM.
; Signature validation occurs when the kernel loads the driver at startup;
; test-signing mode (enabled above) must be active at that point (after reboot).
ExecWait '"$SYSDIR\sc.exe" stop ${DRIVERNAME}' $0
ExecWait '"$SYSDIR\sc.exe" delete ${DRIVERNAME}' $0
IfFileExists $WINDIR\SysWOW64\*.* 0 sccreate_32bit
    ExecWait '"$WINDIR\sysnative\sc.exe" create ${DRIVERNAME} type= filesys start= system error= normal binpath= "\SystemRoot\system32\drivers\${DRIVERNAME}.sys" displayname= "Ext2,3,4 Filesystem Service"' $0
    Goto sccreate_done
sccreate_32bit:
    ExecWait '"$SYSDIR\sc.exe" create ${DRIVERNAME} type= filesys start= system error= normal binpath= "\SystemRoot\system32\drivers\${DRIVERNAME}.sys" displayname= "Ext2,3,4 Filesystem Service"' $0
sccreate_done:

; create the uninstaller.
WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${PROJECTNAME}" \
            "DisplayName" "Ext2,Ext3,Ext4 filesystem driver"
WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${PROJECTNAME}" \
            "UninstallString" '"$INSTDIR\Uninstall.exe"'
WriteUninstaller "Uninstall.exe"

; create the start menu items.
createDirectory "$SMPROGRAMS\${PROJECTNAME}"
createShortCut "$SMPROGRAMS\${PROJECTNAME}\Ext2 Volume Manager.lnk" "$INSTDIR\Ext2Mgr.exe" "" "$INSTDIR\Ext2Mgr.exe" "" SW_SHOWNORMAL "" "Ext2 Volume Manager"
createShortCut "$SMPROGRAMS\${PROJECTNAME}\Uninstall Ext2Fsd.lnk" "$INSTDIR\Uninstall.exe" "" "$INSTDIR\Uninstall.exe" "" SW_SHOWNORMAL "" "Uninstall Ext2Fsd"
createDirectory "$SMPROGRAMS\${PROJECTNAME}\Documents"
createShortCut "$SMPROGRAMS\${PROJECTNAME}\Documents\COPYRIGHT.lnk" "$INSTDIR\Documents\COPYRIGHT.txt" "" "" "" SW_SHOWNORMAL "" "COPYRIGHT"
createShortCut "$SMPROGRAMS\${PROJECTNAME}\Documents\FAQ.lnk" "$INSTDIR\Documents\FAQ.txt" "" "" "" SW_SHOWNORMAL "" "FAQ"
createShortCut "$SMPROGRAMS\${PROJECTNAME}\Documents\Release notes.lnk" "$INSTDIR\Documents\notes.txt" "" "" "" SW_SHOWNORMAL "" "Release notes"
createShortCut "$SMPROGRAMS\${PROJECTNAME}\Documents\README.lnk" "$INSTDIR\Documents\readme.txt" "" "" "" SW_SHOWNORMAL "" "README"

; Install Ext2Srv (the user-mode management service).
ExecWait '"$INSTDIR\Ext2Srv.exe" /installasservice'

; A reboot is required to activate test-signing mode and load the driver.
; The driver service (${DRIVERNAME}) is set to start automatically on boot.
MessageBox MB_ICONINFORMATION|MB_OK \
    "Installation complete.$\n$\nPlease restart your computer to activate the driver.$\n$\nAfter restart, the Ext2Fsd driver will load automatically."
SetRebootFlag true
SectionEnd

Function un.onInit
    SetShellVarContext all

    MessageBox MB_YESNO "This will uninstall ${PROJECTNAME}. Continue?" IDYES continue
        Abort
    continue:

    IfFileExists $WINDIR\SysWOW64\*.* 0 else
        ; 64-bit
        StrCpy $INSTDIR "$PROGRAMFILES64\${PROJECTNAME}"
        Goto endif
    else:
        ; 32-bit
        StrCpy $INSTDIR "$PROGRAMFILES\${PROJECTNAME}"
    endif:
FunctionEnd

Section "Uninstall"
SetShellVarContext all

; Stop and uninstall Ext2Srv (user-mode service).
ExecWait '"net.exe" stop ext2srv'
ExecWait '"$INSTDIR\Ext2Srv.exe" /removeservice'

; Stop and delete the Ext2Fsd driver service.
IfFileExists $WINDIR\SysWOW64\*.* 0 scdel_32bit
    ExecWait '"$WINDIR\sysnative\sc.exe" stop ${DRIVERNAME}' $0
    ExecWait '"$WINDIR\sysnative\sc.exe" delete ${DRIVERNAME}' $0
    Goto scdel_done
scdel_32bit:
    ExecWait '"$SYSDIR\sc.exe" stop ${DRIVERNAME}' $0
    ExecWait '"$SYSDIR\sc.exe" delete ${DRIVERNAME}' $0
scdel_done:

; Remove the test certificate from the machine trust stores.
ExecWait '"$SYSDIR\certutil.exe" -delstore TrustedPublisher "Ext2Fsd Test Certificate"' $0
ExecWait '"$SYSDIR\certutil.exe" -delstore Root "Ext2Fsd Test Certificate"' $0

; Delete the driver binary from System32\drivers.
IfFileExists $WINDIR\SysWOW64\*.* 0 delsys_32bit
    ${DisableX64FSRedirection}
    Delete "$WINDIR\System32\drivers\${DRIVERNAME}.sys"
    ${EnableX64FSRedirection}
    Goto delsys_done
delsys_32bit:
    Delete "$WINDIR\System32\drivers\${DRIVERNAME}.sys"
delsys_done:

; Delete redistributable DLLs (architecture-specific).
IfFileExists $WINDIR\SysWOW64\*.* 0 else
    Delete "$INSTDIR\${VCDLL_X64A}.dll"
    Delete "$INSTDIR\${VCDLL_X64B}.dll"
    Goto endif
else:
    Delete "$INSTDIR\${VCDLL_X86}.dll"
endif:

; delete the start menu items.
Delete "$SMPROGRAMS\${PROJECTNAME}\Documents\COPYRIGHT.lnk"
Delete "$SMPROGRAMS\${PROJECTNAME}\Documents\FAQ.lnk"
Delete "$SMPROGRAMS\${PROJECTNAME}\Documents\Release notes.lnk"
Delete "$SMPROGRAMS\${PROJECTNAME}\Documents\README.lnk"
Delete "$SMPROGRAMS\${PROJECTNAME}\Ext2 Volume Manager.lnk"
Delete "$SMPROGRAMS\${PROJECTNAME}\Uninstall Ext2Fsd.lnk"
RMDir "$SMPROGRAMS\${PROJECTNAME}\Documents"
RMDir "$SMPROGRAMS\${PROJECTNAME}"

; delete the installed files.
Delete $INSTDIR\Documents\COPYRIGHT.txt"
Delete $INSTDIR\Documents\FAQ.txt"
Delete $INSTDIR\Documents\notes.txt"
Delete $INSTDIR\Documents\readme.txt"

Delete $INSTDIR\${DRIVERNAME}.inf
Delete $INSTDIR\${DRIVERNAME}.cat
Delete $INSTDIR\${DRIVERNAME}-TestSign.cer
;Delete $INSTDIR\${DRIVERNAME}.pdb
Delete $INSTDIR\${DRIVERNAME}.sys
Delete $INSTDIR\${MFCDLL}.dll"
Delete $INSTDIR\Ext2Mgr.exe"
Delete $INSTDIR\Ext2Srv.exe"
Delete $INSTDIR\Uninstall.exe

RMDir $INSTDIR\Documents
RMDir $INSTDIR

; delete the reg key for the uninstaller.
DeleteRegKey HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${PROJECTNAME}"
SectionEnd
