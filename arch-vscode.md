sudo mkdir -p /opt/vscode
sudo tar -xzvf code-stable-x64-1787668990.tar.gz -C /opt/vscode --strip-components=1

sudo ln -sf /opt/vscode/bin/code /usr/local/bin/code

cat <<EOF | sudo tee /usr/share/applications/vscode.desktop
[Desktop Entry]
Name=Visual Studio Code
Comment=Code Editing. Redefined.
GenericName=Text Editor
Exec=/opt/vscode/bin/code --unity-launch %F
Icon=/opt/vscode/resources/app/resources/linux/code.png
Type=Application
StartupNotify=false
StartupWMClass=Code
Categories=TextEditor;Development;IDE;
MimeType=text/plain;application/x-code-workspace;
EOF





sudo rm -rf /opt/vscode
sudo rm -f /usr/local/bin/code
sudo rm -f /usr/share/applications/vscode.desktop




-------------------------------------------------
mkdir -p ~/vscode-pkg
cp code-stable-x64-1787668990.tar.gz ~/vscode-pkg/
cd ~/vscode-pkg

cat << 'EOF' > PKGBUILD
pkgname=visualstudiocode
pkgver=1.0
pkgrel=1
pkgdesc="Visual Studio Code"
arch=('x86_64')
license=('custom')
depends=('libxkbfile' 'libsecret' 'nss' 'gtk3' 'alsa-lib')
source=("code-stable-x64-1787668990.tar.gz")
sha256sums=('SKIP')

package() {
    # 1. Install application files to /opt/vscode
    install -d "${pkgdir}/opt/vscode"
    cp -r "${srcdir}"/VSCode-linux-x64/* "${pkgdir}/opt/vscode/"

    # 2. Create executable link in /usr/bin
    install -d "${pkgdir}/usr/bin"
    ln -s /opt/vscode/bin/code "${pkgdir}/usr/bin/code"

    # 3. Create desktop launcher entry
    install -d "${pkgdir}/usr/share/applications"
    cat <<DESKTOP > "${pkgdir}/usr/share/applications/code.desktop"
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

sudo pacman -Rns visual-studio-code-custom