// FAI_WinOP — varsayılan ses çıkış aygıtının seviyesi ve sessizi (Windows Core Audio, COM).
// WindowsAudioProvider bunu Add-Type ile bellekte derler. Windows PowerShell 5.1'in derleyicisi C# 5'tir:
// ifade gövdeli üye, 'out var', metin enterpolasyonu vb. KULLANILMAZ.
using System;
using System.Runtime.InteropServices;

namespace FaiWinOP.Native
{
    [ComImport, Guid("5CDF2C82-841E-4546-9722-0CF74078229A"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    internal interface IAudioEndpointVolume
    {
        [PreserveSig] int RegisterControlChangeNotify(IntPtr notify);
        [PreserveSig] int UnregisterControlChangeNotify(IntPtr notify);
        [PreserveSig] int GetChannelCount(out uint count);
        [PreserveSig] int SetMasterVolumeLevel(float levelDb, ref Guid eventContext);
        [PreserveSig] int SetMasterVolumeLevelScalar(float level, ref Guid eventContext);
        [PreserveSig] int GetMasterVolumeLevel(out float levelDb);
        [PreserveSig] int GetMasterVolumeLevelScalar(out float level);
        [PreserveSig] int SetChannelVolumeLevel(uint channel, float levelDb, ref Guid eventContext);
        [PreserveSig] int SetChannelVolumeLevelScalar(uint channel, float level, ref Guid eventContext);
        [PreserveSig] int GetChannelVolumeLevel(uint channel, out float levelDb);
        [PreserveSig] int GetChannelVolumeLevelScalar(uint channel, out float level);
        [PreserveSig] int SetMute([MarshalAs(UnmanagedType.Bool)] bool mute, ref Guid eventContext);
        [PreserveSig] int GetMute([MarshalAs(UnmanagedType.Bool)] out bool mute);
    }

    [ComImport, Guid("D666063F-1587-4E43-81F1-B948E807363F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    internal interface IMMDevice
    {
        [PreserveSig] int Activate(ref Guid iid, int clsCtx, IntPtr activationParams, [MarshalAs(UnmanagedType.IUnknown)] out object iface);
    }

    [ComImport, Guid("A95664D2-9614-4F35-A746-DE8DB63617E6"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    internal interface IMMDeviceEnumerator
    {
        [PreserveSig] int EnumAudioEndpoints(int dataFlow, int stateMask, out IntPtr devices);
        [PreserveSig] int GetDefaultAudioEndpoint(int dataFlow, int role, out IMMDevice endpoint);
    }

    [ComImport, Guid("BCDE0395-E52F-467C-8E3D-C4579291692E")]
    internal class MMDeviceEnumeratorCom
    {
    }

    public static class AudioEndpoint
    {
        private const int DataFlowRender = 0;   // eRender
        private const int RoleConsole = 0;      // eConsole (varsayılan aygıt)
        private const int ClsCtxAll = 23;
        private const int ElementNotFound = unchecked((int)0x80070490);

        // Varsayılan çıkışın ses arayüzü; aygıt yoksa null.
        private static IAudioEndpointVolume Open()
        {
            IMMDeviceEnumerator enumerator = (IMMDeviceEnumerator)new MMDeviceEnumeratorCom();
            IMMDevice device = null;
            try
            {
                int hr = enumerator.GetDefaultAudioEndpoint(DataFlowRender, RoleConsole, out device);
                if (hr == ElementNotFound) { return null; }
                Marshal.ThrowExceptionForHR(hr);
                if (device == null) { return null; }
                Guid iid = typeof(IAudioEndpointVolume).GUID;
                object iface;
                Marshal.ThrowExceptionForHR(device.Activate(ref iid, ClsCtxAll, IntPtr.Zero, out iface));
                return (IAudioEndpointVolume)iface;
            }
            finally
            {
                if (device != null) { Marshal.ReleaseComObject(device); }
                Marshal.ReleaseComObject(enumerator);
            }
        }

        private static IAudioEndpointVolume OpenOrThrow()
        {
            IAudioEndpointVolume volume = Open();
            if (volume == null) { throw new InvalidOperationException("Varsayılan ses çıkış aygıtı yok."); }
            return volume;
        }

        public static bool HasDevice()
        {
            IAudioEndpointVolume volume = Open();
            if (volume == null) { return false; }
            Marshal.ReleaseComObject(volume);
            return true;
        }

        // 0-100
        public static int GetVolume()
        {
            IAudioEndpointVolume volume = OpenOrThrow();
            try
            {
                float level;
                Marshal.ThrowExceptionForHR(volume.GetMasterVolumeLevelScalar(out level));
                return (int)Math.Round(level * 100.0);
            }
            finally { Marshal.ReleaseComObject(volume); }
        }

        public static void SetVolume(int level)
        {
            if (level < 0 || level > 100) { throw new ArgumentOutOfRangeException("level", "0-100 olmalı"); }
            IAudioEndpointVolume volume = OpenOrThrow();
            try
            {
                Guid context = Guid.Empty;
                Marshal.ThrowExceptionForHR(volume.SetMasterVolumeLevelScalar(level / 100.0f, ref context));
            }
            finally { Marshal.ReleaseComObject(volume); }
        }

        public static bool GetMute()
        {
            IAudioEndpointVolume volume = OpenOrThrow();
            try
            {
                bool mute;
                Marshal.ThrowExceptionForHR(volume.GetMute(out mute));
                return mute;
            }
            finally { Marshal.ReleaseComObject(volume); }
        }

        public static void SetMute(bool mute)
        {
            IAudioEndpointVolume volume = OpenOrThrow();
            try
            {
                Guid context = Guid.Empty;
                Marshal.ThrowExceptionForHR(volume.SetMute(mute, ref context));
            }
            finally { Marshal.ReleaseComObject(volume); }
        }
    }
}
