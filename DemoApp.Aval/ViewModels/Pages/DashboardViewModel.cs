namespace DemoApp.Aval.ViewModels.Pages
{
    public partial class DashboardViewModel : ViewModelBase
    {
        public string DemoMessage { get; } = DemoApp.Shared.DemoReleaseInfo.GetDemoMessage();

        [ObservableProperty]
        private int _counter;

        [RelayCommand]
        private void CounterIncrement()
        {
            Counter++;
        }
    }
}
