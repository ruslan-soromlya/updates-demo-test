using Avalonia;
using Avalonia.Styling;

namespace DemoApp.Aval.ViewModels.Pages
{
    public partial class SettingsViewModel : ViewModelBase
    {
        public string AppVersion { get; } =
            $"DemoApp.Aval - {System.Reflection.Assembly.GetExecutingAssembly().GetName().Version}";

        [ObservableProperty]
        private ThemeVariant _currentTheme = Application.Current?.ActualThemeVariant ?? ThemeVariant.Light;

        public bool IsLightTheme
        {
            get => CurrentTheme == ThemeVariant.Light;
            set
            {
                if (value)
                {
                    ChangeTheme("theme_light");
                }
            }
        }

        public bool IsDarkTheme
        {
            get => CurrentTheme == ThemeVariant.Dark;
            set
            {
                if (value)
                {
                    ChangeTheme("theme_dark");
                }
            }
        }

        [RelayCommand]
        private void ChangeTheme(string parameter)
        {
            CurrentTheme = parameter == "theme_dark" ? ThemeVariant.Dark : ThemeVariant.Light;

            if (Application.Current is not null)
            {
                Application.Current.RequestedThemeVariant = CurrentTheme;
            }
        }

        partial void OnCurrentThemeChanged(ThemeVariant value)
        {
            OnPropertyChanged(nameof(IsLightTheme));
            OnPropertyChanged(nameof(IsDarkTheme));
        }
    }
}
