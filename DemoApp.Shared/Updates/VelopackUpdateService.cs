using Velopack;

namespace DemoApp.Shared.Updates;

public sealed class VelopackUpdateService
{
    private readonly Lock _gate = new();
    private string? _updateSource;
    private UpdateInfo? _availableUpdate;
    private VelopackAsset? _downloadedUpdate;
    private UpdateManager? _updateManager;

    public UpdateCheckResult CurrentState
    {
        get
        {
            var manager = EnsureManager(_updateSource);
            return BuildResult(manager, _availableUpdate, manager.UpdatePendingRestart);
        }
    }

    public async Task<UpdateCheckResult> CheckForUpdatesAsync(string updateSource)
    {
        var manager = EnsureManager(updateSource);

        if (manager.UpdatePendingRestart is { } pendingUpdate)
        {
            _downloadedUpdate = pendingUpdate;
            return BuildResult(manager, _availableUpdate, pendingUpdate);
        }

        if (!manager.IsInstalled)
        {
            return new UpdateCheckResult(
                false,
                false,
                false,
                "Velopack updates are available after the app is packaged and installed.",
                manager.CurrentVersion?.ToString(),
                null,
                null,
                null
            );
        }

        _availableUpdate = await manager.CheckForUpdatesAsync();
        _downloadedUpdate = null;

        return BuildResult(manager, _availableUpdate, null);
    }

    public async Task<UpdateCheckResult> DownloadUpdateAsync(Action<int>? progress = null, CancellationToken cancellationToken = default)
    {
        if (_updateManager is null || _availableUpdate is null)
        {
            throw new InvalidOperationException("Check for updates before downloading.");
        }

        await _updateManager.DownloadUpdatesAsync(_availableUpdate, progress, cancellationToken);
        _downloadedUpdate = _availableUpdate.TargetFullRelease;

        return BuildResult(_updateManager, _availableUpdate, _downloadedUpdate);
    }

    public void ApplyUpdatesAndRestart()
    {
        if (_updateManager is null)
        {
            throw new InvalidOperationException("Check for updates before applying.");
        }

        var updateToApply = _downloadedUpdate ?? _updateManager.UpdatePendingRestart;

        if (updateToApply is null)
        {
            throw new InvalidOperationException("Download an update before applying.");
        }

        _updateManager.ApplyUpdatesAndRestart(updateToApply);
    }

    private UpdateManager EnsureManager(string? updateSource)
    {
        updateSource = NormalizeUpdateSource(updateSource);

        lock (_gate)
        {
            if (_updateManager is null || !StringComparer.OrdinalIgnoreCase.Equals(_updateSource, updateSource))
            {
                _updateSource = updateSource;
                _availableUpdate = null;
                _downloadedUpdate = null;
                _updateManager = new UpdateManager(updateSource);
            }

            return _updateManager;
        }
    }

    private static string NormalizeUpdateSource(string? updateSource)
    {
        if (string.IsNullOrWhiteSpace(updateSource))
        {
            throw new ArgumentException("Enter an update source URL or folder path.", nameof(updateSource));
        }

        return updateSource.Trim();
    }

    private static UpdateCheckResult BuildResult(UpdateManager manager, UpdateInfo? updateInfo, VelopackAsset? downloadedUpdate)
    {
        var targetRelease = downloadedUpdate ?? updateInfo?.TargetFullRelease;

        if (targetRelease is not null)
        {
            return new UpdateCheckResult(
                manager.IsInstalled,
                true,
                downloadedUpdate is not null,
                downloadedUpdate is null ? "Update available." : "Update downloaded. Restart to apply it.",
                manager.CurrentVersion?.ToString(),
                targetRelease.Version.ToString(),
                targetRelease.NotesMarkdown,
                targetRelease.Size
            );
        }

        return new UpdateCheckResult(
            manager.IsInstalled,
            false,
            false,
            manager.IsInstalled ? "You are up to date." : "Velopack updates are available after the app is packaged and installed.",
            manager.CurrentVersion?.ToString(),
            null,
            null,
            null
        );
    }
}
