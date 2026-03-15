cask "screenpath" do
  version "0.4"
  sha256 "df7262ef7b5c71d517a723fe12ca9b4ad2e1e9b40096edfb37c396ad768942db"

  url "https://github.com/Ekwinder/screenpath/releases/download/v#{version}/ScreenPath.app.zip"
  name "ScreenPath"
  desc "Menu bar utility for tracking and reusing screenshot paths"
  homepage "https://github.com/Ekwinder/screenpath"

  app "ScreenPath.app"
end
