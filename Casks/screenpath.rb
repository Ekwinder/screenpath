cask "screenpath" do
  version "0.4.3"
  sha256 "63b349df133ae56bd554cf8c4495b7a430bbc1cfa9673c9bba4f6b85b185fccc"

  url "https://github.com/Ekwinder/screenpath/releases/download/v#{version}/ScreenPath.app.zip"
  name "ScreenPath"
  desc "Menu bar utility for tracking and reusing screenshot paths"
  homepage "https://github.com/Ekwinder/screenpath"

  app "ScreenPath.app"
end
