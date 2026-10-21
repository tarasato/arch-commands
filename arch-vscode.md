## Install without pacman
ARCHIVE="code-stable-x64-1787668990.tar.gz"
APP_DIR="/opt/vscode"

sudo mkdir -p "$APP_DIR"
sudo tar -xzvf "$ARCHIVE" -C "$APP_DIR" --strip-components=1

sudo ln -sf "$APP_DIR/bin/code" /usr/local/bin/code

sudo tee /usr/share/applications/vscode.desktop > /dev/null <<EOF
[Desktop Entry]
Name=Visual Studio Code
Comment=Code Editing. Redefined.
GenericName=Text Editor
Exec=$APP_DIR/bin/code --unity-launch %F
Icon=$APP_DIR/resources/app/resources/linux/code.png
Type=Application
StartupNotify=false
StartupWMClass=Code
Categories=TextEditor;Development;IDE;
MimeType=text/plain;application/x-code-workspace;
EOF

## Uninstall without pacman
APP_DIR="/opt/vscode"

sudo rm -rf "$APP_DIR"
sudo rm -f /usr/local/bin/code
sudo rm -f /usr/share/applications/vscode.desktop




## Install by using pacman
ARCHIVE="code-stable-x64-1787668990.tar.gz"
PKG_DIR="$HOME/vscode-pkg"

mkdir -p "$PKG_DIR"
cp "$ARCHIVE" "$PKG_DIR/"
cd "$PKG_DIR" || exit 1

cat > PKGBUILD <<EOF
pkgname=visualstudiocode
pkgver=1.0
pkgrel=1
pkgdesc="Visual Studio Code"
arch=('x86_64')
license=('custom')
depends=('libxkbfile' 'libsecret' 'nss' 'gtk3' 'alsa-lib')
source=("$ARCHIVE")
sha256sums=('SKIP')

package() {
    install -d "\$pkgdir/opt/vscode"
    cp -r "\$srcdir/VSCode-linux-x64/." "\$pkgdir/opt/vscode/"

    install -d "\$pkgdir/usr/bin"
    ln -s /opt/vscode/bin/code "\$pkgdir/usr/bin/code"

    install -d "\$pkgdir/usr/share/applications"

    cat > "\$pkgdir/usr/share/applications/code.desktop" <<'DESKTOP'
[Desktop Entry]
Name=Visual Studio Code
Comment=Code Editing. Redefined.
GenericName=Text Editor
Exec=/usr/bin/code --unity-launch %F
Icon=/opt/vscode/resources/app/resources/linux/code.png
Type=Application
StartupNotify=false
StartupWMClass=Code
Categories=TextEditor;Development;IDE;
MimeType=text/plain;application/x-code-workspace;
DESKTOP
}
EOF

makepkg -si

## Uninstall by using pacman
sudo pacman -Rns visual-studio-code-custom
