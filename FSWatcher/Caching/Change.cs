namespace FSWatcher.Caching
{
    class Change
    {
        public ChangeType Type { get; private set; }
        public string Item { get; private set; }

        public Change(ChangeType type, string item)
        {
            Type = type;
            Item = item;
        }
    }
}