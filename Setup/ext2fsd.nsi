; ext2fsd.nsi
;
; NSIS installer for the Ext4Fsd project.
; Uses SSDE (Self Signed Driver Enabler) — no test-signing mode, no desktop watermark,
; works with Secure Boot ENABLED.
;
; Build steps:
; 1. Install NSIS
; 2. Compile Ext2Mgr, Ext2Srv and Ext4Fsd (Release x64).
; 3. Ensure Setup\ contains: ssde.sys, ssde_enable.exe, SiPolicy.p7b, Ext2Fsd-sign.cer
; 4. Run: makensis ext2fsd.nsi
;
Unicode true
!include "x64.nsh"

Name "Ext2,Ext3,Ext4 filesystem driver"
!define PROJECTNAME "Ext2Fsd"
!define DRIVERNAME  "Ext2Fsd"
!define CERTCN      "Ext2Fsd Driver"
Icon "..\Ext2Mgr\res\Ext2Mgr.ico"
Caption "${PROJECTNAME} 0.71"
DirText "This is a release of the ${PROJECTNAME} project. You may choose the install directory:"
InstallDir "$PROGRAMFILES\${PROJECTNAME}"
OutFile "${PROJECTNAME}-setup.exe"

; ---------- path defaults (override with /D on the makensis command line) ----------
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
!define VCDLL_X86  "vcruntime140"
!define VCDLL_X64A "vcruntime140"
!define VCDLL_X64B "vcruntime140_1"
!define MFCDLL     "mfc140"

RequestExecutionLevel admin

Function .onInit
    SetShellVarContext all
    IfFileExists $WINDIR\SysWOW64\*.* 0 else
        StrCpy $INSTDIR "$PROGRAMFILES64\${PROJECTNAME}"
        Goto endif
    else:
        StrCpy $INSTDIR "$PROGRAMFILES\${PROJECTNAME}"
    endif:
FunctionEnd

Section "Driver"
SetShellVarContext all

; ---- uninstall old version if present ----
ReadRegStr $0 HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${PROJECTNAME}" \
                   "UninstallString"
StrCmp $0 "" ssde_notice
    ; run old uninstaller silently so we overwrite cleanly
    ExecWait '"$0" /S' $0

ssde_notice:
; ---- SSDE installation notice ----
MessageBox MB_OKCANCEL|MB_ICONINFORMATION \
    "This installer will:$\n$\n \
  \x95 Install the Ext2Fsd filesystem driver$\n \
  \x95 Install the SSDE (Self Signed Driver Enabler) boot service$\n \
  \x95 Deploy the UEFI Secure Boot code-integrity policy$\n$\n \
IMPORTANT: After installation you must enroll the Ext2Fsd signing$\n \
certificate in your UEFI firmware (one-time setup).$\n$\n \
The installer will trigger a reboot sequence to activate SSDE.$\n$\n \
Secure Boot can remain ENABLED. No test-mode watermark." \
    IDOK install_ok
    Abort
install_ok:

; ---- copy files ----
SetOutPath $INSTDIR

IfFileExists $WINDIR\SysWOW64\*.* 0 install_x86
    ; 64-bit
    File "${MSVPATH_X64}\${VCDLL_X64A}.dll"
    File "${MSVPATH_X64}\${VCDLL_X64B}.dll"
    File "${MFCPATH_X64}\${MFCDLL}.dll"
    File "${MGRPATH_X64}\Ext2Mgr.exe"
    File "${SRVPATH_X64}\Ext2Srv.exe"
    File "${SYSPATH_X64}\${DRIVERNAME}.sys"
    File "${SYSPATH_X64}\${DRIVERNAME}.inf"
    File "${SYSPATH_X64}\${DRIVERNAME}.cat"
    File "${SYSPATH_X64}\${DRIVERNAME}-sign.cer"
    Goto install_common
install_x86:
!ifndef X64_ONLY
    File "${MSVPATH_X86}\${VCDLL_X86}.dll"
    File "${MFCPATH_X86}\${MFCDLL}.dll"
    File "${MGRPATH_X86}\Ext2Mgr.exe"
    File "${SRVPATH_X86}\Ext2Srv.exe"
    File "${SYSPATH_X86}\${DRIVERNAME}.sys"
    File "${SYSPATH_X86}\${DRIVERNAME}.inf"
    File "${SYSPATH_X86}\${DRIVERNAME}.cat"
    File "${SYSPATH_X86}\${DRIVERNAME}-sign.cer"
!endif
install_common:

; SSDE support files (architecture-independent — always x64 binaries)
File "ssde.sys"
File "ssde_enable.exe"
File "SiPolicy.p7b"

SetOutPath $INSTDIR\Documents
File "..\ext4fsd\COPYRIGHT.txt"
File "..\ext4fsd\FAQ.txt"
File "..\ext4fsd\notes.txt"
File "..\ext4fsd\readme.txt"

; ---- trust the signing cert in Windows certificate stores ----
; (Needed so Windows Explorer/Device Manager show the driver as trusted)
ExecWait '"$SYSDIR\certutil.exe" -addstore TrustedPublisher "$INSTDIR\${DRIVERNAME}-sign.cer"' $0
ExecWait '"$SYSDIR\certutil.exe" -addstore Root "$INSTDIR\${DRIVERNAME}-sign.cer"' $0

; ---- copy main driver to System32\drivers ----
IfFileExists $WINDIR\SysWOW64\*.* 0 copy_sys_32bit
    ${DisableX64FSRedirection}
    CopyFiles /SILENT "$INSTDIR\${DRIVERNAME}.sys" "$WINDIR\System32\drivers\${DRIVERNAME}.sys"
    ${EnableX64FSRedirection}
    Goto copy_sys_done
copy_sys_32bit:
    CopyFiles /SILENT "$INSTDIR\${DRIVERNAME}.sys" "$WINDIR\System32\drivers\${DRIVERNAME}.sys"
copy_sys_done:

; ---- register main driver service (filesystem, start at system phase) ----
IfFileExists $WINDIR\SysWOW64\*.* 0 sccreate_fsd_32bit
    ExecWait '"$WINDIR\sysnative\sc.exe" stop  ${DRIVERNAME}' $0
    ExecWait '"$WINDIR\sysnative\sc.exe" delete ${DRIVERNAME}' $0
    ExecWait '"$WINDIR\sysnative\sc.exe" create ${DRIVERNAME} type= filesys start= system error= normal binpath= "\SystemRoot\system32\drivers\${DRIVERNAME}.sys" displayname= "Ext2,3,4 Filesystem Service"' $0
    Goto sccreate_fsd_done
sccreate_fsd_32bit:
    ExecWait '"$SYSDIR\sc.exe" stop  ${DRIVERNAME}' $0
    ExecWait '"$SYSDIR\sc.exe" delete ${DRIVERNAME}' $0
    ExecWait '"$SYSDIR\sc.exe" create ${DRIVERNAME} type= filesys start= system error= normal binpath= "\SystemRoot\system32\drivers\${DRIVERNAME}.sys" displayname= "Ext2,3,4 Filesystem Service"' $0
sccreate_fsd_done:

; ---- copy ssde.sys to System32\drivers ----
IfFileExists $WINDIR\SysWOW64\*.* 0 copy_ssde_32bit
    ${DisableX64FSRedirection}
    CopyFiles /SILENT "$INSTDIR\ssde.sys" "$WINDIR\System32\drivers\ssde.sys"
    ${EnableX64FSRedirection}
    Goto copy_ssde_done
copy_ssde_32bit:
    CopyFiles /SILENT "$INSTDIR\ssde.sys" "$WINDIR\System32\drivers\ssde.sys"
copy_ssde_done:

; ---- register ssde as a boot-start kernel driver ----
; ssde.sys runs before any other drivers and keeps the Licensed registry value set,
; which keeps the CustomKernelSigners feature active across reboots.
IfFileExists $WINDIR\SysWOW64\*.* 0 sccreate_ssde_32bit
    ExecWait '"$WINDIR\sysnative\sc.exe" stop  ssde' $0
    ExecWait '"$WINDIR\sysnative\sc.exe" delete ssde' $0
    ExecWait '"$WINDIR\sysnative\sc.exe" create ssde type= kernel start= boot error= normal binpath= "\SystemRoot\system32\drivers\ssde.sys" displayname= "Self Signed Driver Enabler"' $0
    Goto sccreate_ssde_done
sccreate_ssde_32bit:
    ExecWait '"$SYSDIR\sc.exe" stop  ssde' $0
    ExecWait '"$SYSDIR\sc.exe" delete ssde' $0
    ExecWait '"$SYSDIR\sc.exe" create ssde type= kernel start= boot error= normal binpath= "\SystemRoot\system32\drivers\ssde.sys" displayname= "Self Signed Driver Enabler"' $0
sccreate_ssde_done:

; ---- deploy SiPolicy.p7b to the EFI System Partition ----
; This policy allows kernel code signed by any Authenticode-trusted cert to load.
; mountvol assigns the ESP a temporary drive letter (X:).
IfFileExists $WINDIR\SysWOW64\*.* 0 mount_efi_32bit
    ExecWait '"$WINDIR\sysnative\mountvol.exe" X: /s' $0
    CopyFiles /SILENT "$INSTDIR\SiPolicy.p7b" "X:\EFI\Microsoft\Boot\SiPolicy.p7b"
    ExecWait '"$WINDIR\sysnative\mountvol.exe" X: /d' $0
    Goto mount_efi_done
mount_efi_32bit:
    ExecWait '"$SYSDIR\mountvol.exe" X: /s' $0
    CopyFiles /SILENT "$INSTDIR\SiPolicy.p7b" "X:\EFI\Microsoft\Boot\SiPolicy.p7b"
    ExecWait '"$SYSDIR\mountvol.exe" X: /d' $0
mount_efi_done:

; ---- install Ext2Srv (user-mode management service) ----
ExecWait '"$INSTDIR\Ext2Srv.exe" /installasservice'

; ---- create uninstaller and start menu shortcuts ----
WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${PROJECTNAME}" \
            "DisplayName" "Ext2,Ext3,Ext4 filesystem driver"
WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${PROJECTNAME}" \
            "UninstallString" '"$INSTDIR\Uninstall.exe"'
WriteUninstaller "Uninstall.exe"

createDirectory "$SMPROGRAMS\${PROJECTNAME}"
createShortCut "$SMPROGRAMS\${PROJECTNAME}\Ext2 Volume Manager.lnk"    "$INSTDIR\Ext2Mgr.exe"    "" "$INSTDIR\Ext2Mgr.exe"    "" SW_SHOWNORMAL "" "Ext2 Volume Manager"
createShortCut "$SMPROGRAMS\${PROJECTNAME}\Uninstall Ext2Fsd.lnk"      "$INSTDIR\Uninstall.exe"  "" "$INSTDIR\Uninstall.exe"  "" SW_SHOWNORMAL "" "Uninstall Ext2Fsd"
createDirectory "$SMPROGRAMS\${PROJECTNAME}\Documents"
createShortCut "$SMPROGRAMS\${PROJECTNAME}\Documents\COPYRIGHT.lnk"    "$INSTDIR\Documents\COPYRIGHT.txt" "" "" "" SW_SHOWNORMAL "" "COPYRIGHT"
createShortCut "$SMPROGRAMS\${PROJECTNAME}\Documents\FAQ.lnk"          "$INSTDIR\Documents\FAQ.txt"       "" "" "" SW_SHOWNORMAL "" "FAQ"
createShortCut "$SMPROGRAMS\${PROJECTNAME}\Documents\Release notes.lnk" "$INSTDIR\Documents\notes.txt"   "" "" "" SW_SHOWNORMAL "" "Release notes"
createShortCut "$SMPROGRAMS\${PROJECTNAME}\Documents\README.lnk"       "$INSTDIR\Documents\readme.txt"   "" "" "" SW_SHOWNORMAL "" "README"

; ---- UEFI enrollment instructions ----
; The user MUST add Ext2Fsd-sign.cer to Secure Boot DB and KEK in firmware.
; Without this the signed driver will be rejected even with Licensed=1.
MessageBox MB_ICONINFORMATION|MB_OK \
    "IMPORTANT: UEFI Certificate Enrollment Required$\n$\n \
Before the driver can load you must enroll the Ext2Fsd signing certificate$\n \
in your UEFI firmware's Secure Boot key database.$\n$\n \
Certificate file: $INSTDIR\${DRIVERNAME}-sign.cer$\n$\n \
Steps:$\n \
  1. Copy ${DRIVERNAME}-sign.cer to a USB drive (FAT32)$\n \
  2. Reboot and enter UEFI firmware (usually F2 / DEL / F10)$\n \
  3. Navigate to: Security > Secure Boot > Key Management$\n \
  4. Enroll ${DRIVERNAME}-sign.cer into both DB and KEK$\n \
  5. Save and exit$\n$\n \
After UEFI enrollment click OK — the installer will activate SSDE.$\n \
The system will reboot twice automatically to complete setup."

; ---- activate SSDE (triggers reboot ? WinRE ? back) ----
; ssde_enable.exe sets HKLM\...\CI\Protected\Licensed=1 via a WinRE boot cycle.
; ssde.sys (start=boot) then keeps Licensed=1 on all subsequent boots.
ExecWait '"$INSTDIR\ssde_enable.exe"' $0

; ---- done ----
MessageBox MB_ICONINFORMATION|MB_OK \
    "Installation complete.$\n$\n \
The system will now reboot to activate SSDE (Self Signed Driver Enabler).$\n$\n \
After the automatic reboot sequence finishes, mount an ext2/3/4 volume$\n \
to confirm the driver loads correctly."
SetRebootFlag true
SectionEnd

; ---------------------------------------------------------------------------

Function un.onInit
    SetShellVarContext all

    MessageBox MB_YESNO "This will uninstall ${PROJECTNAME}. Continue?" IDYES un_continue
        Abort
    un_continue:

    IfFileExists $WINDIR\SysWOW64\*.* 0 else
        StrCpy $INSTDIR "$PROGRAMFILES64\${PROJECTNAME}"
        Goto endif
    else:
        StrCpy $INSTDIR "$PROGRAMFILES\${PROJECTNAME}"
    endif:
FunctionEnd

Section "Uninstall"
SetShellVarContext all

; Stop and uninstall Ext2Srv (user-mode service)
ExecWait '"net.exe" stop ext2srv'
ExecWait '"$INSTDIR\Ext2Srv.exe" /removeservice'

; Stop and delete the Ext2Fsd driver service
IfFileExists $WINDIR\SysWOW64\*.* 0 scdel_fsd_32bit
    ExecWait '"$WINDIR\sysnative\sc.exe" stop  ${DRIVERNAME}' $0
    ExecWait '"$WINDIR\sysnative\sc.exe" delete ${DRIVERNAME}' $0
    Goto scdel_fsd_done
scdel_fsd_32bit:
    ExecWait '"$SYSDIR\sc.exe" stop  ${DRIVERNAME}' $0
    ExecWait '"$SYSDIR\sc.exe" delete ${DRIVERNAME}' $0
scdel_fsd_done:

; Stop and delete the ssde boot service
IfFileExists $WINDIR\SysWOW64\*.* 0 scdel_ssde_32bit
    ExecWait '"$WINDIR\sysnative\sc.exe" stop  ssde' $0
    ExecWait '"$WINDIR\sysnative\sc.exe" delete ssde' $0
    Goto scdel_ssde_done
scdel_ssde_32bit:
    ExecWait '"$SYSDIR\sc.exe" stop  ssde' $0
    ExecWait '"$SYSDIR\sc.exe" delete ssde' $0
scdel_ssde_done:

; Remove the signing cert from Windows trust stores
ExecWait '"$SYSDIR\certutil.exe" -delstore TrustedPublisher "${CERTCN}"' $0
ExecWait '"$SYSDIR\certutil.exe" -delstore Root              "${CERTCN}"' $0

; Remove SiPolicy.p7b from the EFI System Partition
IfFileExists $WINDIR\SysWOW64\*.* 0 unmount_efi_32bit
    ExecWait '"$WINDIR\sysnative\mountvol.exe" X: /s' $0
    Delete "X:\EFI\Microsoft\Boot\SiPolicy.p7b"
    ExecWait '"$WINDIR\sysnative\mountvol.exe" X: /d' $0
    Goto unmount_efi_done
unmount_efi_32bit:
    ExecWait '"$SYSDIR\mountvol.exe" X: /s' $0
    Delete "X:\EFI\Microsoft\Boot\SiPolicy.p7b"
    ExecWait '"$SYSDIR\mountvol.exe" X: /d' $0
unmount_efi_done:

; Remove driver binaries from System32\drivers
IfFileExists $WINDIR\SysWOW64\*.* 0 delsys_32bit
    ${DisableX64FSRedirection}
    Delete "$WINDIR\System32\drivers\${DRIVERNAME}.sys"
    Delete "$WINDIR\System32\drivers\ssde.sys"
    ${EnableX64FSRedirection}
    Goto delsys_done
delsys_32bit:
    Delete "$WINDIR\System32\drivers\${DRIVERNAME}.sys"
    Delete "$WINDIR\System32\drivers\ssde.sys"
delsys_done:

; Delete redistributable DLLs
IfFileExists $WINDIR\SysWOW64\*.* 0 else
    Delete "$INSTDIR\${VCDLL_X64A}.dll"
    Delete "$INSTDIR\${VCDLL_X64B}.dll"
    Goto endif
else:
    Delete "$INSTDIR\${VCDLL_X86}.dll"
endif:

; Delete start menu shortcuts
Delete "$SMPROGRAMS\${PROJECTNAME}\Documents\COPYRIGHT.lnk"
Delete "$SMPROGRAMS\${PROJECTNAME}\Documents\FAQ.lnk"
Delete "$SMPROGRAMS\${PROJECTNAME}\Documents\Release notes.lnk"
Delete "$SMPROGRAMS\${PROJECTNAME}\Documents\README.lnk"
Delete "$SMPROGRAMS\${PROJECTNAME}\Ext2 Volume Manager.lnk"
Delete "$SMPROGRAMS\${PROJECTNAME}\Uninstall Ext2Fsd.lnk"
RMDir "$SMPROGRAMS\${PROJECTNAME}\Documents"
RMDir "$SMPROGRAMS\${PROJECTNAME}"

; Delete installed files
Delete "$INSTDIR\Documents\COPYRIGHT.txt"
Delete "$INSTDIR\Documents\FAQ.txt"
Delete "$INSTDIR\Documents\notes.txt"
Delete "$INSTDIR\Documents\readme.txt"
Delete "$INSTDIR\${DRIVERNAME}.inf"
Delete "$INSTDIR\${DRIVERNAME}.cat"
Delete "$INSTDIR\${DRIVERNAME}-sign.cer"
Delete "$INSTDIR\${DRIVERNAME}.sys"
Delete "$INSTDIR\ssde.sys"
Delete "$INSTDIR\ssde_enable.exe"
Delete "$INSTDIR\SiPolicy.p7b"
Delete "$INSTDIR\${MFCDLL}.dll"
Delete "$INSTDIR\Ext2Mgr.exe"
Delete "$INSTDIR\Ext2Srv.exe"
Delete "$INSTDIR\Uninstall.exe"

RMDir "$INSTDIR\Documents"
RMDir "$INSTDIR"

; Delete the uninstall registry key
DeleteRegKey HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${PROJECTNAME}"
SectionEnd
