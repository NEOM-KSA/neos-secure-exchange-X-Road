#!/bin/bash
set -e
LAST_SUPPORTED_VERSION=6.26.0

function builddeb {
    local root="$1"
    local dist="$2"
    local suffix="$3"
    local release="$4"

    pushd "$(pwd)"
    cd "$root/$dist"
    cp ../generic/* debian/
    version="$(dpkg-parsechangelog -l../generic/changelog | sed -n -e 's/^Version: //p')"
    compat="$(cat debian/compat)"
    sed -i "s/\${debhelper-version}/$compat/" debian/control

    for p in $(dh_listpackages); do
      if ! [ -f "debian/$p.preinst" ]; then
        echo "Generating $p.preinst"
        cat <<EOF >"debian/$p.preinst"
#!/bin/bash
if [ "\$1" = "upgrade" ]; then
  if dpkg --compare-versions "$LAST_SUPPORTED_VERSION" gt "\$2"; then
    echo "ERROR: Upgrade supported from version $LAST_SUPPORTED_VERSION or newer" >&2
    exit 1
  fi
fi
#DEBHELPER#
exit 0
EOF
      fi
    done
    sed -i "s/#LAST_SUPPORTED_VERSION#/${LAST_SUPPORTED_VERSION}/" debian/*.preinst

    if [[ $release != "-release" ]]; then
        version=$version."$(date --utc --date @`git show -s --format=%ct` +'%Y%m%d%H%M%S')$(git show -s --format=git%h --abbrev=7)"
    else
        export DEB_BUILD_OPTIONS=release
    fi

    dch -b -v "$version.$suffix" "Build for $dist"
    dch --distribution $dist -r ""
    dpkg-buildpackage -tc -b -us -uc
    popd

    find $root -name "xroad*$suffix*.deb" -exec mv {} "build/$suffix/" \;
}

function prepare {
    mkdir -p "build/$1"
    rm -f "build/$1/"*.deb
}

DIR="$(cd "$(dirname $0)" && pwd)"
cd "$DIR"

mkdir -p build/xroad
mkdir -p build/xroad-jetty9
cp -a src/xroad/ubuntu build/xroad/
cp -a src/xroad-jetty9/ubuntu build/xroad-jetty9/
./download_jetty.sh

case "$1" in
    bionic)
        prepare ubuntu18.04
        builddeb build/xroad/ubuntu bionic ubuntu18.04 "$2"
        builddeb build/xroad-jetty9/ubuntu bionic ubuntu18.04 "$2"
        ;;
    focal)
        prepare ubuntu20.04
        builddeb build/xroad/ubuntu focal ubuntu20.04 "$2"
        builddeb build/xroad-jetty9/ubuntu focal ubuntu20.04 "$2"
        ;;
    *)
        echo "Unsupported distribution $dist"
        exit 1;
        ;;
esac
