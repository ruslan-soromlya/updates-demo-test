using DemoApp.Windows.ViewModels.Pages;
using Wpf.Ui.Abstractions.Controls;

namespace DemoApp.Windows.Views.Pages
{
    public partial class UpdatePage : INavigableView<UpdateViewModel>
    {
        public UpdateViewModel ViewModel { get; }

        public UpdatePage(UpdateViewModel viewModel)
        {
            ViewModel = viewModel;
            DataContext = this;

            InitializeComponent();
        }
    }
}
