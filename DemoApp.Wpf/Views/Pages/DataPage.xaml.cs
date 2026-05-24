using DemoApp.Wpf.ViewModels.Pages;
using Wpf.Ui.Abstractions.Controls;

namespace DemoApp.Wpf.Views.Pages
{
    public partial class DataPage : INavigableView<DataViewModel>
    {
        public DataViewModel ViewModel { get; }

        public DataPage(DataViewModel viewModel)
        {
            ViewModel = viewModel;
            DataContext = this;

            InitializeComponent();
        }
    }
}
