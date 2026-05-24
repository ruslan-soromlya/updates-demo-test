namespace DemoApp.Aval.ViewModels
{
    public partial class MainWindowViewModel : ViewModelBase
    {
        public string ApplicationTitle { get; } = "Avalonia UI - DemoApp.Aval";

        public IReadOnlyList<NavigationItemViewModel> MenuItems { get; }

        public IReadOnlyList<NavigationItemViewModel> FooterMenuItems { get; }

        [ObservableProperty]
        private NavigationItemViewModel _selectedMenuItem;

        [ObservableProperty]
        private ViewModelBase _currentPage;

        public MainWindowViewModel()
        {
            MenuItems =
            [
                new("Home", "Home", new Pages.DashboardViewModel(), SelectMenuItem),
                new("Data", "Data", new Pages.DataViewModel(), SelectMenuItem)
            ];

            FooterMenuItems =
            [
                new("Settings", "Settings", new Pages.SettingsViewModel(), SelectMenuItem)
            ];

            _selectedMenuItem = MenuItems[0];
            _currentPage = _selectedMenuItem.Page;
        }

        private void SelectMenuItem(NavigationItemViewModel item)
        {
            SelectedMenuItem = item;
            CurrentPage = item.Page;
        }
    }
}
