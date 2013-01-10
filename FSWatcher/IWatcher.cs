using System;
using FSWatcher.Initialization;

namespace FSWatcher
{
    public interface IWatcher : IDisposable
    {
        WatcherSettings Settings { get; }
        void Watch();
        void ForceRefresh();
        void StopWatching();
        void ErrorNotifier(Action<string, Exception> notifier);
    }
}