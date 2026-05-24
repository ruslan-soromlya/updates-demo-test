namespace DemoApp.Windows.ViewModels.Pages
{
    public partial class DashboardViewModel : ObservableObject
    {
        public string DemoMessage { get; } = DemoApp.Shared.DemoReleaseInfo.GetDemoMessage();

        [ObservableProperty]
        private int _counter = 0;

        [RelayCommand]
        private void OnCounterIncrement()
        {
            Counter++;
        }
    }
}
