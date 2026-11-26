# The VMDance window's File menu, open on its Quick export submenu, for the
# guide (figures.tcl, on Windows). figures.tcl opens the File menu as a
# popup under the menubar (tk_popup, which waits until the menu closes);
# this script, run in the background meanwhile, finds that menu among VMD's
# own windows (class #32768, of VMD's process), and posts to it the keys
# that walk down to Quick export and open it, then takes the picture and
# closes the menus. The keys are messages to VMD's menu windows, never
# keystrokes: no other program's window can receive them.
#   powershell -NoProfile -ExecutionPolicy Bypass -File capture_menu.ps1 <vmd-pid> <0x-frame> <file.png> [downs]
param([Parameter(Mandatory = $true)][int]$VmdPid,
      [Parameter(Mandatory = $true)][string]$Frame,
      [Parameter(Mandatory = $true)][string]$Out,
      [int]$Downs = 7)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;
public static class VmdanceMenu {
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
    public delegate bool EnumProc(IntPtr h, IntPtr l);
    [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc f, IntPtr l);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll")] public static extern int GetClassName(IntPtr h, StringBuilder s, int n);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint msg, IntPtr w, IntPtr l);
    // the visible menus (#32768) of a process
    public static List<IntPtr> Menus(uint pid) {
        var found = new List<IntPtr>();
        EnumWindows((h, l) => {
            uint p; GetWindowThreadProcessId(h, out p);
            if (p == pid && IsWindowVisible(h)) {
                var c = new StringBuilder(64); GetClassName(h, c, 64);
                if (c.ToString() == "#32768") found.Add(h);
            }
            return true;
        }, IntPtr.Zero);
        return found;
    }
    public static void Key(IntPtr h, int vk) {
        PostMessage(h, 0x0100, (IntPtr)vk, IntPtr.Zero);            // WM_KEYDOWN
        PostMessage(h, 0x0101, (IntPtr)vk, (IntPtr)(-1073741823));  // WM_KEYUP
    }
}
"@
[VmdanceMenu]::SetProcessDPIAware() | Out-Null
$VK_DOWN = 0x28; $VK_RIGHT = 0x27; $VK_ESCAPE = 0x1B
# the File menu, once open
$menus = @()
for ($t = 0; $t -lt 100 -and $menus.Count -eq 0; $t++) {
    Start-Sleep -Milliseconds 100
    $menus = @([VmdanceMenu]::Menus([uint32]$VmdPid))
}
if ($menus.Count -eq 0) { throw "no menu of process $VmdPid opened" }
$file = $menus[0]
Start-Sleep -Milliseconds 400
for ($i = 0; $i -lt $Downs; $i++) { [VmdanceMenu]::Key($file, $VK_DOWN); Start-Sleep -Milliseconds 120 }
[VmdanceMenu]::Key($file, $VK_RIGHT)
Start-Sleep -Milliseconds 900
try {
    # from the window's top left to past the menus' bottom right
    $fr = New-Object VmdanceMenu+RECT
    $h = [IntPtr]::new([Convert]::ToInt64(($Frame -replace '^0x', ''), 16))
    [VmdanceMenu]::GetWindowRect($h, [ref]$fr) | Out-Null
    $right = 0; $bottom = 0
    foreach ($m in [VmdanceMenu]::Menus([uint32]$VmdPid)) {
        $r = New-Object VmdanceMenu+RECT
        [VmdanceMenu]::GetWindowRect($m, [ref]$r) | Out-Null
        $right = [Math]::Max($right, $r.Right); $bottom = [Math]::Max($bottom, $r.Bottom)
    }
    $x = $fr.Left + 8; $y = $fr.Top
    $w = $right + 16 - $x; $ht = $bottom + 16 - $y
    $bmp = New-Object System.Drawing.Bitmap $w, $ht
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.CopyFromScreen($x, $y, 0, 0, (New-Object System.Drawing.Size $w, $ht))
    $g.Dispose()
    $bmp.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
} finally {
    # closed: Escape to each menu, the submenu first
    for ($t = 0; $t -lt 20; $t++) {
        $open = @([VmdanceMenu]::Menus([uint32]$VmdPid))
        if ($open.Count -eq 0) { break }
        foreach ($m in $open) { [VmdanceMenu]::Key($m, $VK_ESCAPE) }
        Start-Sleep -Milliseconds 250
    }
}
