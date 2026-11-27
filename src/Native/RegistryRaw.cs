// FAI_WinOP — ham kayıt defteri değeri (REG_NONE / bilinmeyen tür): tür numarası + bayt aynen okunur / yazılır.
// WindowsRegistryProvider.GetRawValue / SetRawValue kullanır. Windows PowerShell 5.1'in derleyicisi C# 5'tir.
using System;
using System.Runtime.InteropServices;
using Microsoft.Win32.SafeHandles;

namespace FaiWinOP.Native
{
    public static class RegistryRaw
    {
        [DllImport("advapi32.dll", CharSet = CharSet.Unicode, EntryPoint = "RegQueryValueExW")]
        public static extern int QueryValue(SafeRegistryHandle hKey, string name, IntPtr reserved, out int type, byte[] data, ref int size);

        [DllImport("advapi32.dll", CharSet = CharSet.Unicode, EntryPoint = "RegSetValueExW")]
        public static extern int SetValue(SafeRegistryHandle hKey, string name, int reserved, int type, byte[] data, int size);
    }
}
