using Avalonia.Controls;
using System;
using System.Diagnostics;
using System.IO;
using System.Text;
using System.Threading.Tasks;

namespace DemoApp.ReleaseTool.Views
{
    public partial class MainWindow : Window
    {
        private readonly string _repoRoot;
        private readonly string _scriptPath;
        private readonly string _notesPath;

        public MainWindow()
        {
            InitializeComponent();

            _repoRoot = LocateRepositoryRoot();
            _scriptPath = Path.Combine(_repoRoot, "scripts", "Build-VelopackReleases.ps1");
            _notesPath = Path.Combine(_repoRoot, "artifacts", "release-notes", "demo-tool-notes.md");

            DemoMessageBox.Text =
                $"Local demo build created at {DateTime.Now:t}";

            ReleaseNotesBox.Text =
                "# Local Demo Build\r\n\r\n" +
                "- This build is generated locally via Velopack\r\n" +
                "- No CI or GitHub Pages involved\r\n";

            //// ❌ REMOVE misleading UI coupling to LocalAppData
            //AvaloniaFeedBox.Text = "Local build (auto-managed by script)";
            //WindowsFeedBox.Text = "Local build (auto-managed by script)";
        }

        private async void BuildButton_Click(object? sender, Avalonia.Interactivity.RoutedEventArgs e)
        {
            BuildButton.IsEnabled = false;
            StatusText.Text = "Building local update...";
            OutputBox.Text = string.Empty;

            try
            {
                Directory.CreateDirectory(Path.GetDirectoryName(_notesPath)!);

                await File.WriteAllTextAsync(
                    _notesPath,
                    ReleaseNotesBox.Text ?? string.Empty,
                    Encoding.UTF8
                );

                var startInfo = new ProcessStartInfo
                {
                    FileName = "pwsh", // better than "powershell"
                    WorkingDirectory = _repoRoot,
                    UseShellExecute = false,
                    RedirectStandardOutput = true,
                    RedirectStandardError = true,
                    CreateNoWindow = true
                };

                startInfo.ArgumentList.Add("-NoProfile");
                startInfo.ArgumentList.Add("-ExecutionPolicy");
                startInfo.ArgumentList.Add("Bypass");
                startInfo.ArgumentList.Add("-File");
                startInfo.ArgumentList.Add(_scriptPath);

                // ✅ ALWAYS LOCAL MODE
                startInfo.ArgumentList.Add("-Mode");
                startInfo.ArgumentList.Add("Local");

                startInfo.ArgumentList.Add("-DemoMessage");
                startInfo.ArgumentList.Add(DemoMessageBox.Text ?? string.Empty);

                startInfo.ArgumentList.Add("-ReleaseNotes");
                startInfo.ArgumentList.Add(_notesPath);

                using var process = new Process { StartInfo = startInfo, EnableRaisingEvents = true };

                process.OutputDataReceived += (_, args) => AppendOutput(args.Data);
                process.ErrorDataReceived += (_, args) => AppendOutput(args.Data);

                process.Start();
                process.BeginOutputReadLine();
                process.BeginErrorReadLine();

                await process.WaitForExitAsync();

                StatusText.Text = process.ExitCode == 0
                    ? "Local build completed successfully"
                    : $"Build failed (exit code {process.ExitCode})";
            }
            catch (Exception ex)
            {
                StatusText.Text = "Build failed";
                AppendOutput(ex.ToString());
            }
            finally
            {
                BuildButton.IsEnabled = true;
            }
        }

        private void OpenFolderButton_Click(object? sender, Avalonia.Interactivity.RoutedEventArgs e)
        {
            var releaseRoot =
                Path.Combine(
                    Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                    "DemoApp",
                    "Releases"
                );

            Directory.CreateDirectory(releaseRoot);

            Process.Start(new ProcessStartInfo
            {
                FileName = releaseRoot,
                UseShellExecute = true
            });
        }

        private void AppendOutput(string? value)
        {
            if (string.IsNullOrWhiteSpace(value))
                return;

            Avalonia.Threading.Dispatcher.UIThread.Post(() =>
            {
                OutputBox.Text += value + Environment.NewLine;
                OutputBox.CaretIndex = OutputBox.Text.Length;
            });
        }

        private static string LocateRepositoryRoot()
        {
            var dir = AppContext.BaseDirectory;

            while (!string.IsNullOrWhiteSpace(dir))
            {
                if (File.Exists(Path.Combine(dir, "DemoApp.slnx")))
                    return dir;

                dir = Directory.GetParent(dir)?.FullName;
            }

            return Path.GetFullPath(Path.Combine(AppContext.BaseDirectory, "..", "..", "..", ".."));
        }
    }
}