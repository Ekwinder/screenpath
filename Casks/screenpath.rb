cask "screenpath" do
  version "0.4.2"
  sha256 "f314adafc1412519a9ba7a30b3dde9542a8897ac996fc0a64438165eb0bf9e93"

  url "https://github.com/Ekwinder/screenpath/releases/download/v#{version}/ScreenPath.app.zip"
  name "ScreenPath"
  desc "Menu bar utility for tracking and reusing screenshot paths"
  homepage "https://github.com/Ekwinder/screenpath"

  app "ScreenPath.app"
end
