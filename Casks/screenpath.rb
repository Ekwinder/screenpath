cask "screenpath" do
  version "0.3"
  sha256 "43c64b50c50a22178866844b13e49d873e7b05a98934b9dcd297c6320c0bbdee"

  url "https://github.com/Ekwinder/screenpath/releases/download/v#{version}/ScreenPath.app.zip"
  name "ScreenPath"
  desc "Menu bar utility for tracking and reusing screenshot paths"
  homepage "https://github.com/Ekwinder/screenpath"

  app "ScreenPath.app"
end
