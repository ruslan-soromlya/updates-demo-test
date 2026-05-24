namespace DemoApp.Aval.ViewModels
{
    public sealed class NavigationItemViewModel
    {
        public NavigationItemViewModel(string title, string icon, ViewModelBase page, Action<NavigationItemViewModel> select)
        {
            Title = title;
            Icon = icon;
            Page = page;
            SelectCommand = new RelayCommand(() => select(this));
        }

        public string Title { get; }

        public string Icon { get; }

        public ViewModelBase Page { get; }

        public IRelayCommand SelectCommand { get; }
    }
}
