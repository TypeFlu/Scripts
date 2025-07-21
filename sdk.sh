#!/usr/bin/env bash

set -e

# --- COLOR DEFINITIONS ---
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
RED="\033[1;31m"
BLUE="\033[1;34m"
NC="\033[0m" # No Color

step() { echo -e "${BLUE}==>${NC} ${GREEN}$1${NC}"; }
warn() { echo -e "${YELLOW}Warning:${NC} $1"; }
error() { echo -e "${RED}Error:${NC} $1"; }
progress_bar() {
  local pid=$!
  local delay=0.1
  local spinstr='|/-\'
  echo -ne " "
  while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
    local temp=${spinstr#?}
    printf " [%c]  " "$spinstr"
    local spinstr=$temp${spinstr%"$temp"}
    sleep $delay
    printf "\b\b\b\b\b\b"
  done
  echo -ne "\r"
}

# --- DETECT SHELL & RC FILE ---
if [[ "$SHELL" =~ "zsh" ]]; then
  RC_FILE="$HOME/.zshrc"
else
  RC_FILE="$HOME/.bashrc"
fi

# --- STEP 1: UPDATE SYSTEM ---
step "Updating system packages"
sudo apt-get update -y & progress_bar
sudo apt-get upgrade -y & progress_bar

# --- STEP 2: INSTALL BUILD TOOLS ---
step "Installing build essentials and wget, unzip"
sudo apt-get install -y build-essential wget unzip curl & progress_bar

# --- STEP 3: INSTALL LATEST ECLIPSE TEMURIN JDK ---
step "Installing latest Eclipse Temurin JDK"
TEMURIN_LATEST=$(curl -s https://api.adoptium.net/v3/info/release_names?image_type=jdk | grep -m1 -o 'jdk-[0-9]\+\.[0-9]\+\.[0-9]\+_hotspot')
TEMURIN_URL=$(curl -s "https://api.adoptium.net/v3/assets/latest/$(echo $TEMURIN_LATEST | cut -d- -f2)/ga?architecture=x64&heap_size=normal&image_type=jdk&os=linux" | grep -oP '"binary_link":"\K[^"]*')
wget -qO /tmp/temurin.tar.gz "$TEMURIN_URL" & progress_bar
sudo mkdir -p /opt/java
sudo tar -xzf /tmp/temurin.tar.gz -C /opt/java & progress_bar
JAVA_DIR=$(find /opt/java -type d -name "jdk*" | head -n 1)
echo "export JAVA_HOME=$JAVA_DIR" >> "$RC_FILE"
export JAVA_HOME="$JAVA_DIR"
echo 'export PATH=$JAVA_HOME/bin:$PATH' >> "$RC_FILE"
export PATH="$JAVA_HOME/bin:$PATH"

# --- STEP 4: INSTALL ANDROID COMMAND LINE TOOLS ---
ANDROID_SDK_ROOT="$HOME/Android/Sdk"
mkdir -p "$ANDROID_SDK_ROOT/cmdline-tools"
step "Getting latest Android Command Line Tools"
TOOLS_URL=$(curl -s https://developer.android.com/studio | grep -oP 'https://dl.google.com/android/repository/commandlinetools-linux-[^"]+' | head -1)
wget -qO /tmp/commandlinetools.zip "$TOOLS_URL" & progress_bar
unzip -qo /tmp/commandlinetools.zip -d "$ANDROID_SDK_ROOT/cmdline-tools" & progress_bar
mv "$ANDROID_SDK_ROOT/cmdline-tools/cmdline-tools" "$ANDROID_SDK_ROOT/cmdline-tools/latest"

# --- STEP 5: SET ENVIRONMENT VARIABLES ---
echo "export ANDROID_HOME=$ANDROID_SDK_ROOT" >> "$RC_FILE"
echo "export ANDROID_SDK_ROOT=$ANDROID_SDK_ROOT" >> "$RC_FILE"
echo 'export PATH=$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH' >> "$RC_FILE"
export ANDROID_HOME="$ANDROID_SDK_ROOT"
export ANDROID_SDK_ROOT="$ANDROID_SDK_ROOT"
export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH"

# --- STEP 6: INSTALL SDK PACKAGES & LICENSES ---
step "Installing Android SDK Tools, Platform-tools, Build-tools"
yes | sdkmanager --sdk_root="$ANDROID_SDK_ROOT" "platform-tools" "platforms;android-34" "build-tools;34.0.0" & progress_bar
yes | sdkmanager --licenses & progress_bar

# --- STEP 7: INSTALL LATEST GRADLE ---
step "Installing latest Gradle"
GRADLE_LATEST=$(curl -s https://services.gradle.org/versions/current | grep -o '"version":"[^"]*' | head -1 | cut -d'"' -f4)
GRADLE_ZIP="gradle-$GRADLE_LATEST-bin.zip"
wget -qO /tmp/$GRADLE_ZIP "https://services.gradle.org/distributions/$GRADLE_ZIP" & progress_bar
sudo unzip -qo /tmp/$GRADLE_ZIP -d /opt/gradle & progress_bar
echo "export PATH=/opt/gradle/gradle-$GRADLE_LATEST/bin:\$PATH" >> "$RC_FILE"
export PATH="/opt/gradle/gradle-$GRADLE_LATEST/bin:$PATH"

# --- STEP 8: FINAL STATUS ---
step "Validating Installation"
echo -e "${GREEN}✔ JAVA:$(java -version 2>&1 | head -1)${NC}"
echo -e "${GREEN}✔ Android SDK:$(sdkmanager --version)${NC}"
echo -e "${GREEN}✔ Gradle:$(gradle -v | grep Gradle)${NC}"
echo -e "${BLUE}All done! Open a new terminal or source your rc file for changes to apply.${NC}"

