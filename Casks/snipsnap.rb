cask "snipsnap" do
  version "1.0.2"
  sha256 "0ad0d2c3bbc5ebc7ca5c4f905a0bb6acf8bcdfe8b40f4441b190ef7e3f62e02a"

  url "https://github.com/iskf/SnipSnap/releases/download/v#{version}/SnipSnap-#{version}.dmg"
  name "SnipSnap"
  desc "Native macOS screenshot, pinning, OCR, and Safari-style in-place translation tool"
  homepage "https://github.com/iskf/SnipSnap"

  depends_on macos: ">= :sonoma"

  app "SnipSnap.app"

  zap trash: [
    "~/Library/Application Support/SnipSnap",
    "~/Library/Caches/com.snipsnap.app",
    "~/Library/Preferences/com.snipsnap.app.plist",
  ]
end
