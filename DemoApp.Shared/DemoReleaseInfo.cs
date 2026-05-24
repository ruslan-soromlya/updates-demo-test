using System.Reflection;

namespace DemoApp.Shared;

public static class DemoReleaseInfo
{
    public const string DefaultDemoMessage = "This is the original demo screen.";

    public static string ReleaseRoot =>
        Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "DemoApp", "Releases");

    public static string AvaloniaReleasePath => Path.Combine(ReleaseRoot, "demoaval");

    public static string WindowsReleasePath => Path.Combine(ReleaseRoot, "demowindows");

    public static string GetDemoMessage()
    {
        return GetMetadataValue("DemoMessage", DefaultDemoMessage);
    }

    public static string GetUpdateSource(string fallback)
    {
        return GetMetadataValue("DemoUpdateSource", fallback);
    }

    private static string GetMetadataValue(string key, string fallback)
    {
        var assembly = Assembly.GetEntryAssembly() ?? Assembly.GetExecutingAssembly();
        var metadata = assembly
            .GetCustomAttributes<AssemblyMetadataAttribute>()
            .FirstOrDefault(attribute => attribute.Key == key);

        return string.IsNullOrWhiteSpace(metadata?.Value)
            ? fallback
            : metadata.Value;
    }
}
