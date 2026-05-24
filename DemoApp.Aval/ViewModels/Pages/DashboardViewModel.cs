namespace DemoApp.Aval.ViewModels.Pages
{
    public partial class DashboardViewModel : ViewModelBase
    {
        [ObservableProperty]
        private int _counter;

        [RelayCommand]
        private void CounterIncrement()
        {
            Counter++;
        }
    }
}
