using DemoApp.Shared.Updates;
using DemoApp.Shared;
using Wpf.Ui.Abstractions.Controls;

namespace DemoApp.Windows.ViewModels.Pages
{
    public partial class UpdateViewModel : ObservableObject, INavigationAware
    {
        private readonly VelopackUpdateService _updateService;

        [ObservableProperty]
        private string _updateSource = Environment.GetEnvironmentVariable("DEMOAPP_UPDATE_URL")
            ?? DemoReleaseInfo.GetUpdateSource(DemoReleaseInfo.WindowsReleasePath);

        [ObservableProperty]
        private string _status = "Ready to check for updates.";

        [ObservableProperty]
        private string _currentVersion = "Unknown";

        [ObservableProperty]
        private string _targetVersion = "None";

        [ObservableProperty]
        private string _releaseNotes = "No release notes loaded.";

        [ObservableProperty]
        [NotifyPropertyChangedFor(nameof(IsIdle))]
        private bool _isBusy;

        [ObservableProperty]
        private int _downloadProgress;

        [ObservableProperty]
        [NotifyCanExecuteChangedFor(nameof(DownloadUpdateCommand))]
        private bool _hasUpdate;

        [ObservableProperty]
        [NotifyCanExecuteChangedFor(nameof(ApplyUpdateCommand))]
        private bool _isUpdateDownloaded;

        public bool IsIdle => !IsBusy;

        public UpdateViewModel(VelopackUpdateService updateService)
        {
            _updateService = updateService;
        }

        public Task OnNavigatedToAsync() => Task.CompletedTask;

        public Task OnNavigatedFromAsync() => Task.CompletedTask;

        [RelayCommand]
        private async Task CheckForUpdatesAsync()
        {
            await RunUpdateOperationAsync(async () =>
            {
                DownloadProgress = 0;
                Status = "Checking for updates...";
                ApplyResult(await _updateService.CheckForUpdatesAsync(UpdateSource));
            });
        }

        [RelayCommand(CanExecute = nameof(CanDownloadUpdate))]
        private async Task DownloadUpdateAsync()
        {
            await RunUpdateOperationAsync(async () =>
            {
                Status = "Downloading update...";
                ApplyResult(await _updateService.DownloadUpdateAsync(progress => DownloadProgress = progress));
            });
        }

        [RelayCommand(CanExecute = nameof(CanApplyUpdate))]
        private void ApplyUpdate()
        {
            Status = "Restarting to apply update...";
            _updateService.ApplyUpdatesAndRestart();
        }

        private bool CanDownloadUpdate() => HasUpdate && !IsUpdateDownloaded && !IsBusy;

        private bool CanApplyUpdate() => IsUpdateDownloaded && !IsBusy;

        private async Task RunUpdateOperationAsync(Func<Task> operation)
        {
            try
            {
                IsBusy = true;
                DownloadUpdateCommand.NotifyCanExecuteChanged();
                ApplyUpdateCommand.NotifyCanExecuteChanged();

                await operation();
            }
            catch (Exception ex)
            {
                Status = ex.Message;
            }
            finally
            {
                IsBusy = false;
                DownloadUpdateCommand.NotifyCanExecuteChanged();
                ApplyUpdateCommand.NotifyCanExecuteChanged();
            }
        }

        private void ApplyResult(UpdateCheckResult result)
        {
            Status = result.Message;
            CurrentVersion = result.CurrentVersion ?? "Unknown";
            TargetVersion = result.TargetVersion ?? "None";
            ReleaseNotes = string.IsNullOrWhiteSpace(result.ReleaseNotesMarkdown)
                ? "No release notes available."
                : result.ReleaseNotesMarkdown;
            HasUpdate = result.HasUpdate;
            IsUpdateDownloaded = result.IsDownloaded;
        }
    }
}
