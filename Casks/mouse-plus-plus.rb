cask "mouse-plus-plus" do
  version :latest
  sha256 :no_check

  url "https://github.com/5eanxlee/smooth-scroll.git",
      verified: "github.com/5eanxlee/smooth-scroll/",
      using:    :git,
      branch:   "main"
  name "Mouse++"
  name "Smooth Scroll"
  desc "Menu bar app for smooth, trackpad-like mouse wheel scrolling"
  homepage "https://github.com/5eanxlee/smooth-scroll"

  livecheck do
    skip "Built from the latest source on the main branch"
  end

  depends_on formula: "librsvg"
  depends_on macos: :ventura

  app "Homebrew/Mouse++.app"

  preflight do
    system_command "/bin/zsh",
                   args: ["./install.sh"],
                   cwd:  staged_path,
                   env:  {
                     "SMOOTH_SCROLL_INSTALL_DIR" => "#{staged_path}/Homebrew",
                     "SMOOTH_SCROLL_SKIP_OPEN"   => "1",
                   }
  end

  uninstall launchctl: "com.local.SmoothScroll",
            quit:      "com.local.SmoothScroll",
            delete:    "~/Library/LaunchAgents/com.local.SmoothScroll.plist"

  zap trash: [
    "~/Library/Logs/Mouse++",
    "~/Library/Preferences/com.local.SmoothScroll.plist",
  ]

  caveats <<~EOS
    Mouse++ requires Accessibility permission, and may also need Input Monitoring.
    Open System Settings > Privacy & Security after first launch if scrolling is not active.

    For Homebrew installs, update with:
      brew upgrade --cask --greedy-latest mouse-plus-plus
  EOS
end
