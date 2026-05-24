namespace DemoApp.Shared.Updates;

public sealed record UpdateCheckResult(
    bool IsInstalled,
    bool HasUpdate,
    bool IsDownloaded,
    string Message,
    string? CurrentVersion,
    string? TargetVersion,
    string? ReleaseNotesMarkdown,
    long? PackageSizeBytes
);
