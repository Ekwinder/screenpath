cask "screenpath" do
  version "0.4"
  sha256 "30fdd7ff9e60d1cff844bdb931b9339eb7a581922d261789d21ea15cd937657c"

  url "https://github.com/Ekwinder/screenpath/releases/download/v#{version}/ScreenPath.app.zip"
  name "ScreenPath"
  desc "Menu bar utility for tracking and reusing screenshot paths"
  homepage "https://github.com/Ekwinder/screenpath"

  app "ScreenPath.app"
end
