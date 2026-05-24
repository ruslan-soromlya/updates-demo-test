using Avalonia.Media;
using DemoApp.Aval.Models;

namespace DemoApp.Aval.ViewModels.Pages
{
    public partial class DataViewModel : ViewModelBase
    {
        public IReadOnlyList<DataColor> Colors { get; }

        public DataViewModel()
        {
            var random = new Random();
            var colors = new List<DataColor>();

            for (var i = 0; i < 8192; i++)
            {
                colors.Add(
                    new DataColor(
                        new SolidColorBrush(
                            Color.FromArgb(
                                200,
                                (byte)random.Next(0, 250),
                                (byte)random.Next(0, 250),
                                (byte)random.Next(0, 250)
                            )
                        )
                    )
                );
            }

            Colors = colors;
        }
    }
}
