cask "snipsnap" do
  version "1.0.0"
  sha256 "c469721576c4e31915447d68cc0624361bc8a7b13f3be6956705a3207018a5a4"

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
