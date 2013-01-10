namespace FSWatcher.Initialization
{
    public class WatcherSettings
	{
        public bool ContinuousPolling {
            get {
                var supportsAll =
                    CanDetectEventedDirectoryCreate &&
                    CanDetectEventedDirectoryDelete &&
                    CanDetectEventedDirectoryRename &&
                    CanDetectEventedFileCreate &&
                    CanDetectEventedFileChange &&
                    CanDetectEventedFileDelete &&
                    CanDetectEventedFileRename;
                return !supportsAll;
            }
        }

		public bool CanDetectEventedDirectoryCreate { get; private set; }
		public bool CanDetectEventedDirectoryDelete { get; private set; }
		public bool CanDetectEventedDirectoryRename { get; private set; }
		public bool CanDetectEventedFileCreate { get; private set; }
		public bool CanDetectEventedFileChange { get; private set; }
		public bool CanDetectEventedFileDelete { get; private set; }
		public bool CanDetectEventedFileRename { get; private set; }
        public int PollFrequency { get; private set; }

		public WatcherSettings(
			bool canDetectDirectoryCreate,
			bool canDetectDirectoryDelete,
			bool canDetectDirectoryRename,
			bool canDetectFileCreate,
			bool canDetectFileChange,
			bool canDetectFileDelete,
			bool canDetectFileRename)
		{
			CanDetectEventedDirectoryCreate = canDetectDirectoryCreate;
			CanDetectEventedDirectoryDelete = canDetectDirectoryDelete;
			CanDetectEventedDirectoryRename = canDetectDirectoryRename;
			CanDetectEventedFileCreate = canDetectFileCreate;
			CanDetectEventedFileChange = canDetectFileChange;
			CanDetectEventedFileDelete = canDetectFileDelete;
			CanDetectEventedFileRename = canDetectFileRename;
            PollFrequency = 100;
		}

        public void SetPollFrequencyTo(int milliseconds)
        {
            if (milliseconds > 100)
                PollFrequency = milliseconds;
        }
    }
}
