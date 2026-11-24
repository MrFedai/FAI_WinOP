// FAI_WinOP — kabuk yenileme (duvar kağıdı, masaüstü rengi, ayar yayını) ve ham kayıt defteri değeri (özel türlü).
// WindowsDesktopProvider ve WindowsAppSettingsProvider bunu Add-Type ile bellekte derler. Windows PowerShell 5.1'in
// derleyicisi C# 5'tir: ifade gövdeli üye, 'out var', metin enterpolasyonu vb. KULLANILMAZ.
using System;
using System.Runtime.InteropServices;
using Microsoft.Win32;
using Microsoft.Win32.SafeHandles;

namespace FaiWinOP.Native
{
    public static class ShellNative
    {
        private const uint SPI_SETDESKWALLPAPER = 0x0014;
        private const uint SPIF_UPDATEINIFILE = 0x01;
        private const uint SPIF_SENDCHANGE = 0x02;
        private const int COLOR_DESKTOP = 1;
        private const uint WM_SETTINGCHANGE = 0x001A;
        private const uint SMTO_ABORTIFHUNG = 0x0002;

        [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        private static extern bool SystemParametersInfo(uint action, uint param, string vparam, uint winIni);

        [DllImport("user32.dll", SetLastError = true)]
        private static extern bool SetSysColors(int count, int[] elements, int[] colors);

        [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        private static extern IntPtr SendMessageTimeout(IntPtr hWnd, uint msg, UIntPtr wParam, string lParam, uint flags, uint timeout, out UIntPtr result);

        [DllImport("advapi32.dll", CharSet = CharSet.Unicode)]
        private static extern int RegQueryValueEx(SafeRegistryHandle key, string name, IntPtr reserved, out int type, byte[] data, ref int size);

        [DllImport("advapi32.dll", CharSet = CharSet.Unicode)]
        private static extern int RegSetValueEx(SafeRegistryHandle key, string name, int reserved, int type, byte[] data, int size);

        // Boş yol = duvar kağıdı yok (düz renk).
        public static void SetWallpaper(string path)
        {
            if (!SystemParametersInfo(SPI_SETDESKWALLPAPER, 0, path ?? "", SPIF_UPDATEINIFILE | SPIF_SENDCHANGE))
            {
                throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());
            }
        }

        // Masaüstü düz rengi (yalnız bu oturum; kalıcı değer HKCU\Control Panel\Colors\Background).
        public static void SetDesktopColor(int red, int green, int blue)
        {
            int colorref = (red & 0xFF) | ((green & 0xFF) << 8) | ((blue & 0xFF) << 16);
            if (!SetSysColors(1, new int[] { COLOR_DESKTOP }, new int[] { colorref }))
            {
                throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());
            }
        }

        // Bütün üst düzey pencerelere WM_SETTINGCHANGE (ör. "ImmersiveColorSet": koyu / açık tema).
        public static void BroadcastSettingChange(string area)
        {
            UIntPtr result;
            SendMessageTimeout(new IntPtr(0xFFFF), WM_SETTINGCHANGE, UIntPtr.Zero, area, SMTO_ABORTIFHUNG, 3000, out result);
        }

        // Değerin ham türü ve verisi; değer yoksa false.
        public static bool QueryRaw(RegistryKey key, string name, out int type, out byte[] data)
        {
            type = 0;
            data = null;
            int size = 0;
            int rc = RegQueryValueEx(key.Handle, name, IntPtr.Zero, out type, null, ref size);
            if (rc == 2) { return false; }
            if (rc != 0 && rc != 234) { throw new System.ComponentModel.Win32Exception(rc); }
            data = new byte[size];
            rc = RegQueryValueEx(key.Handle, name, IntPtr.Zero, out type, data, ref size);
            if (rc != 0) { throw new System.ComponentModel.Win32Exception(rc); }
            if (size != data.Length) { Array.Resize(ref data, size); }
            return true;
        }

        public static void SetRaw(RegistryKey key, string name, int type, byte[] data)
        {
            int rc = RegSetValueEx(key.Handle, name, 0, type, data, data.Length);
            if (rc != 0) { throw new System.ComponentModel.Win32Exception(rc); }
        }
    }
}
