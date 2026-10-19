#!/bin/sh
# tools/vsix.sh [out.vsix] (#191): editors/vscode as a .vsix, the package
# VS Code installs with `code --install-extension`, made with zip alone,
# without npm's vsce. A .vsix is a zip of [Content_Types].xml,
# extension.vsixmanifest, and the extension's files under extension/.
# The name, publisher and version come from editors/vscode/package.json;
# the package goes to build/<name>-<version>.vsix unless out is given,
# and its path is printed.
set -eu
cd "$(dirname "$0")/.."
src=editors/vscode

# a top-level string of package.json, which keeps one key to a line
field() { sed -n "s/^  \"$1\": \"\\(.*\\)\",\$/\\1/p" "$src/package.json" | head -n 1; }
xml() { printf '%s' "$1" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g'; }
name=$(field name)
publisher=$(field publisher)
version=$(field version)
display=$(field displayName)
description=$(field description)
engine=$(sed -n 's/^    "vscode": "\(.*\)"$/\1/p' "$src/package.json" | head -n 1)
for v in name publisher version engine; do
    eval "[ -n \"\$$v\" ]" || { echo "tools/vsix.sh: no $v in $src/package.json" >&2; exit 1; }
done
command -v zip >/dev/null 2>&1 || { echo "tools/vsix.sh: zip is needed" >&2; exit 1; }

out=${1:-build/$name-$version.vsix}
case $out in /*) ;; *) out=$(pwd)/$out ;; esac
mkdir -p "$(dirname "$out")"

# the trap removes $tmp: it is the directory mktemp made, or the script ends
tmp=$(mktemp -d "${TMPDIR:-/tmp}/kelvin-vsix.XXXXXX") || exit 1
[ -d "$tmp" ] || exit 1
trap 'rm -rf "$tmp"' EXIT

mkdir "$tmp/extension"
cp -R "$src/." "$tmp/extension/"
cp LICENSE "$tmp/extension/LICENSE"
cat >"$tmp/[Content_Types].xml" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension=".json" ContentType="application/json"/>
  <Default Extension=".md" ContentType="text/markdown"/>
  <Default Extension=".vsixmanifest" ContentType="text/xml"/>
  <Default Extension="" ContentType="text/plain"/>
</Types>
EOF
cat >"$tmp/extension.vsixmanifest" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<PackageManifest Version="2.0.0" xmlns="http://schemas.microsoft.com/developer/vsx-schema/2011" xmlns:d="http://schemas.microsoft.com/developer/vsx-schema-design/2011">
  <Metadata>
    <Identity Language="en-US" Id="$(xml "$name")" Version="$(xml "$version")" Publisher="$(xml "$publisher")"/>
    <DisplayName>$(xml "$display")</DisplayName>
    <Description xml:space="preserve">$(xml "$description")</Description>
    <Categories>Programming Languages</Categories>
    <Properties>
      <Property Id="Microsoft.VisualStudio.Code.Engine" Value="$(xml "$engine")"/>
    </Properties>
  </Metadata>
  <Installation>
    <InstallationTarget Id="Microsoft.VisualStudio.Code"/>
  </Installation>
  <Dependencies/>
  <Assets>
    <Asset Type="Microsoft.VisualStudio.Code.Manifest" Path="extension/package.json" Addressable="true"/>
    <Asset Type="Microsoft.VisualStudio.Services.Content.Details" Path="extension/README.md" Addressable="true"/>
    <Asset Type="Microsoft.VisualStudio.Services.Content.License" Path="extension/LICENSE" Addressable="true"/>
  </Assets>
</PackageManifest>
EOF
rm -f "$out"
(cd "$tmp" && zip -qrX "$out" '[Content_Types].xml' extension.vsixmanifest extension)
echo "$out"
