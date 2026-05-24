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
        private readonly string _releaseRoot;
        private readonly string _notesPath;

        public MainWindow()
        {
            InitializeComponent();

            _repoRoot = LocateRepositoryRoot();
            _scriptPath = Path.Combine(_repoRoot, "scripts", "Build-VelopackReleases.ps1");
            _releaseRoot = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                "DemoApp",
                "Releases"
            );
            _notesPath = Path.Combine(_repoRoot, "artifacts", "release-notes", "demo-tool-notes.md");

            DemoMessageBox.Text = $"Demo update created at {DateTime.Now:t}.";
            ReleaseNotesBox.Text = "# Demo update\r\n\r\n- The Home page message changed.\r\n- The app found and installed this update from a local Velopack feed.";
            AvaloniaFeedBox.Text = Path.Combine(_releaseRoot, "demoaval");
            WindowsFeedBox.Text = Path.Combine(_releaseRoot, "demowindows");
        }

        private async void BuildButton_Click(object? sender, Avalonia.Interactivity.RoutedEventArgs e)
        {
            BuildButton.IsEnabled = false;
            StatusText.Text = "Building update...";
            OutputBox.Text = string.Empty;

            try
            {
                Directory.CreateDirectory(Path.GetDirectoryName(_notesPath)!);
                await File.WriteAllTextAsync(_notesPath, ReleaseNotesBox.Text ?? string.Empty, Encoding.UTF8);

                var startInfo = new ProcessStartInfo
                {
                    FileName = "powershell",
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
                startInfo.ArgumentList.Add("-DemoMessage");
                startInfo.ArgumentList.Add(DemoMessageBox.Text ?? string.Empty);
                startInfo.ArgumentList.Add("-ReleaseNotes");
                startInfo.ArgumentList.Add(_notesPath);
                startInfo.ArgumentList.Add("-AvaloniaReleaseDir");
                startInfo.ArgumentList.Add(AvaloniaFeedBox.Text ?? string.Empty);
                startInfo.ArgumentList.Add("-WindowsReleaseDir");
                startInfo.ArgumentList.Add(WindowsFeedBox.Text ?? string.Empty);

                using var process = new Process { StartInfo = startInfo, EnableRaisingEvents = true };
                process.OutputDataReceived += (_, args) => AppendOutput(args.Data);
                process.ErrorDataReceived += (_, args) => AppendOutput(args.Data);

                process.Start();
                process.BeginOutputReadLine();
                process.BeginErrorReadLine();
                await process.WaitForExitAsync();

                StatusText.Text = process.ExitCode == 0
                    ? "Update packages created"
                    : $"Build failed with exit code {process.ExitCode}";
            }
            catch (Exception ex)
            {
                StatusText.Text = "Build failed";
                AppendOutput(ex.Message);
            }
            finally
            {
                BuildButton.IsEnabled = true;
            }
        }

        private void OpenFolderButton_Click(object? sender, Avalonia.Interactivity.RoutedEventArgs e)
        {
            Directory.CreateDirectory(_releaseRoot);
            Process.Start(new ProcessStartInfo
            {
                FileName = _releaseRoot,
                UseShellExecute = true
            });
        }

        private void AppendOutput(string? value)
        {
            if (string.IsNullOrWhiteSpace(value))
            {
                return;
            }

            Avalonia.Threading.Dispatcher.UIThread.Post(() =>
            {
                OutputBox.Text += value + Environment.NewLine;
                OutputBox.CaretIndex = OutputBox.Text.Length;
            });
        }

        private static string LocateRepositoryRoot()
        {
            var directory = AppContext.BaseDirectory;

            while (!string.IsNullOrWhiteSpace(directory))
            {
                if (File.Exists(Path.Combine(directory, "DemoApp.slnx")))
                {
                    return directory;
                }

                directory = Directory.GetParent(directory)?.FullName;
            }

            return Path.GetFullPath(Path.Combine(AppContext.BaseDirectory, "..", "..", "..", ".."));
        }
    }
}
