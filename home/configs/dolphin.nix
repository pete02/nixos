{ ... }:
{
  home.file.".local/share/applications/feh.desktop".text = ''
    [Desktop Entry]
    Name=feh
    Comment=Open images in feh
    Exec=feh %f
    Terminal=false
    Type=Application
    MimeType=image/png;image/jpeg;image/gif;image/bmp;
    Icon=utilities-terminal
    Categories=Graphics;Viewer;
    NoDisplay=false
  '';

  home.file.".config/mimeapps.list".text = ''
    [Default Applications]
    image/png=feh.desktop
    image/jpeg=feh.desktop
    image/gif=feh.desktop
    image/bmp=feh.desktop
  '';
}
