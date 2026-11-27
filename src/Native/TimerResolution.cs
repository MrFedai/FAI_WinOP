// FAI_WinOP — zamanlayıcı çözünürlüğü servisi (FAI_TimerResolution).
// WindowsTimerResolutionProvider bunu Add-Type ile bir .exe'ye derler ve Windows servisi olarak kurar.
// Kullanım (servis ImagePath'i): FAI_TimerResolution.exe <çözünürlük, 100 ns birimi; varsayılan 5000 = 0,5 ms>
// Servis çalıştıkça istek geçerlidir; durunca bırakılır.
// Not: Windows 11'de istek yalnız bu süreci etkiler; sistem geneli için
// HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\kernel\GlobalTimerResolutionRequests = 1 (DWORD) gerekir.
// Windows PowerShell 5.1'in derleyicisi C# 5'tir: yeni sözdizimi KULLANILMAZ.
using System;
using System.Runtime.InteropServices;
using System.ServiceProcess;

namespace FaiWinOP.Native
{
    public class TimerResolutionService : ServiceBase
    {
        public const string DefaultServiceName = "FAI_TimerResolution";

        [DllImport("ntdll.dll")]
        private static extern int NtSetTimerResolution(uint desiredResolution, [MarshalAs(UnmanagedType.U1)] bool setResolution, out uint currentResolution);

        // Maximum = en kaba (ör. 156250), Minimum = en ince (ör. 5000) çözünürlük.
        [DllImport("ntdll.dll")]
        private static extern int NtQueryTimerResolution(out uint maximumResolution, out uint minimumResolution, out uint currentResolution);

        private readonly uint desired;
        private uint applied;

        public TimerResolutionService(uint desired)
        {
            this.ServiceName = DefaultServiceName;
            this.CanStop = true;
            this.CanShutdown = true;
            this.desired = desired;
        }

        protected override void OnStart(string[] args)
        {
            uint coarsest, finest, current;
            NtQueryTimerResolution(out coarsest, out finest, out current);
            uint want = desired;
            if (want < finest) { want = finest; }
            if (want > coarsest) { want = coarsest; }
            NtSetTimerResolution(want, true, out current);
            applied = want;
        }

        protected override void OnStop() { Release(); }

        protected override void OnShutdown() { Release(); }

        private void Release()
        {
            if (applied == 0) { return; }
            uint current;
            NtSetTimerResolution(applied, false, out current);
            applied = 0;
        }
    }

    public static class TimerResolutionProgram
    {
        public static void Main(string[] args)
        {
            uint desired = 5000;
            if (args.Length > 0)
            {
                uint parsed;
                if (UInt32.TryParse(args[0], out parsed)) { desired = parsed; }
            }
            ServiceBase.Run(new TimerResolutionService(desired));
        }
    }
}
