using DemoApp.Wpf.ViewModels.Pages;
using Wpf.Ui.Abstractions.Controls;

namespace DemoApp.Wpf.Views.Pages
{
    public partial class DashboardPage : INavigableView<DashboardViewModel>
    {
        public DashboardViewModel ViewModel { get; }

        public DashboardPage(DashboardViewModel viewModel)
        {
            ViewModel = viewModel;
            DataContext = this;

            InitializeComponent();
        }
    }
}
