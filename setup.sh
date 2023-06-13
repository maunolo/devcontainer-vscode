#!/bin/sh
set -e

THEME="https://github.com/denysdovhan/spaceship-prompt"
PLUGINS="git ssh-agent https://github.com/zsh-users/zsh-autosuggestions https://github.com/zsh-users/zsh-completions https://github.com/z-shell/F-Sy-H"
ZSHRC_APPEND=$(cat << EOF
SPACESHIP_PROMPT_ADD_NEWLINE=false
SPACESHIP_USER_SHOW=always
SPACESHIP_PROMPT_ADD_NEWLINE=false
SPACESHIP_CHAR_SYMBOL="❯"
SPACESHIP_CHAR_SUFFIX=" "
EOF
)

echo
echo "Installing Oh-My-Zsh with:"
echo "  THEME   = $THEME"
echo "  PLUGINS = $PLUGINS"
echo "  ZSHRC_APPEND = $ZSHRC_APPEND"
echo

check_dist() {
    (
        . /etc/os-release
        echo $ID
    )
}

check_version() {
    (
        . /etc/os-release
        echo $VERSION_ID
    )
}

install_dependencies() {
    DIST=`check_dist`
    VERSION=`check_version`
    echo "###### Installing dependencies for $DIST"

    if [ "`id -u`" = "0" ]; then
        Sudo=''
    elif which sudo; then
        Sudo='sudo'
    else
        echo "WARNING: 'sudo' command not found. Skipping the installation of dependencies. "
        echo "If this fails, you need to do one of these options:"
        echo "   1) Install 'sudo' before calling this script"
        echo "OR"
        echo "   2) Install the required dependencies: git curl zsh"
        return
    fi

    case $DIST in
        alpine)
            $Sudo apk add --update --no-cache git curl zsh ssh build-base cmake coreutils curl unzip gettext-tiny-dev
        ;;
        centos | amzn)
            $Sudo yum update -y
            $Sudo yum install -y git curl ssh ninja-build cmake gcc make unzip gettext
            $Sudo yum install -y ncurses-compat-libs # this is required for AMZN Linux (ref: https://github.com/emqx/emqx/issues/2503)
            $Sudo curl http://mirror.ghettoforge.org/distributions/gf/el/7/plus/x86_64/zsh-5.1-1.gf.el7.x86_64.rpm > zsh-5.1-1.gf.el7.x86_64.rpm
            $Sudo rpm -i zsh-5.1-1.gf.el7.x86_64.rpm
            $Sudo rm zsh-5.1-1.gf.el7.x86_64.rpm
        ;;
        *)
            $Sudo apt-get update
            $Sudo apt-get -y install git curl zsh locales ssh ninja-build gettext cmake unzip
            if [ "$VERSION" != "14.04" ]; then
                $Sudo apt-get -y install locales-all
            fi
            $Sudo locale-gen en_US.UTF-8
    esac
}

zshrc_template() {
    _HOME=$1;
    _THEME=$2; shift; shift
    _PLUGINS=$*;

    cat <<EOM
export LANG='en_US.UTF-8'
export LANGUAGE='en_US:en'
export LC_ALL='en_US.UTF-8'
export TERM=xterm

##### Zsh/Oh-my-Zsh Configuration
export ZSH="$_HOME/.oh-my-zsh"

ZSH_THEME="${_THEME}"
plugins=($_PLUGINS)

alias vim='nvim'

EOM
    printf "$ZSHRC_APPEND"
    printf "\nsource \$ZSH/oh-my-zsh.sh\n"
}

install_nvim() {
    if ! command -v nvim &> /dev/null
    then
        echo "###### Downloading nvim source"

        curl -L -o nvim.tar.gz https://github.com/neovim/neovim/archive/refs/tags/stable.tar.gz

        echo "###### Extracting nvim"

        tar xzf nvim.tar.gz

        echo "###### Building nvim"

        cd neovim-stable
        make CMAKE_BUILD_TYPE=Release
        make install
        cd ..

        rm -rf neovim-stable nvim.tar.gz
    fi

    echo "###### Clonning Packer"

    PACKER_DIR="$HOME/.local/share/nvim/site/pack/packer/start/packer.nvim"
    if [ ! -d "$PACKER_DIR" ]; then
        git clone --depth 1 https://github.com/wbthomason/packer.nvim $PACKER_DIR
    fi
    
    echo "###### Packer Sync"

    nvim --headless --noplugin -c 'autocmd User PackerComplete quitall' -c 'PackerSync'
}

install_dependencies

cd /tmp

# Install On-My-Zsh
if [ ! -d $HOME/.oh-my-zsh ]; then
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

# Generate plugin list
plugin_list=""
for plugin in $PLUGINS; do
    if [ "`echo $plugin | grep -E '^http.*'`" != "" ]; then
        plugin_name=`basename $plugin`
        git clone $plugin $HOME/.oh-my-zsh/custom/plugins/$plugin_name
    else
        plugin_name=$plugin
    fi
    plugin_list="${plugin_list}$plugin_name "
done

# Handle themes
if [ "`echo $THEME | grep -E '^http.*'`" != "" ]; then
    theme_repo=`basename $THEME`
    THEME_DIR="$HOME/.oh-my-zsh/custom/themes/$theme_repo"
    git clone $THEME $THEME_DIR
    theme_name=`cd $THEME_DIR; ls *.zsh-theme | head -1`
    theme_name="${theme_name%.zsh-theme}"
    THEME="$theme_repo/$theme_name"
fi

# Generate .zshrc
zshrc_template "$HOME" "$THEME" "$plugin_list" > $HOME/.zshrc

install_nvim

