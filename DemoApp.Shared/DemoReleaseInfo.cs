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
        var assembly = Assembly.GetEntryAssembly() ?? Assembly.GetExecutingAssembly();
        var metadata = assembly
            .GetCustomAttributes<AssemblyMetadataAttribute>()
            .FirstOrDefault(attribute => attribute.Key == "DemoMessage");

        return string.IsNullOrWhiteSpace(metadata?.Value)
            ? DefaultDemoMessage
            : metadata.Value;
    }
}
