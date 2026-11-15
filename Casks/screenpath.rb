cask "screenpath" do
  version "0.4.4"
  sha256 "879a0803f182bfdb9d56d1c81f19a752d587ddf312d9a4a7be62dace88fe63a1"

  url "https://github.com/Ekwinder/screenpath/releases/download/v#{version}/ScreenPath.app.zip"
  name "ScreenPath"
  desc "Menu bar utility for tracking and reusing screenshot paths"
  homepage "https://github.com/Ekwinder/screenpath"

  app "ScreenPath.app"
end
