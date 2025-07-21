#!/usr/bin/env bash

set -e

# ──────────────────────────────────────────────────────────────── #
# 🎨 Terminal Colors
# ──────────────────────────────────────────────────────────────── #
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
RED="\033[1;31m"
BLUE="\033[1;34m"
CYAN="\033[1;36m"
NC="\033[0m"

print_banner() {
  echo -e "${CYAN}"
  echo "═══════════════════════════════════════════════════"
  echo " 🧰 Android CLI Dev Setup for Ubuntu (Pro Edition)"
  echo "═══════════════════════════════════════════════════"
  echo -e "${NC}"
}

prompt_input() {
  local var_name="$1"
  local message="$2"
  local default="$3"

  printf "${YELLOW}${message}${NC} "
  if [[ -n "$default" ]]; then
    printf "[Default: ${GREEN}${default}${NC}]: "
  fi
  read -r input
  eval "$var_name=\"\${input:-$default}\""
}

confirm() {
  read -p "$(echo -e "${YELLOW}❯❯ $1 (y/n):${NC} ")" -n 1 -r
  echo
  [[ $REPLY =~ ^[Yy]$ ]]
}

add_to_shell_profile() {
  local content="$1"
  local shellrc="$HOME/.bashrc"
  [[ "$SHELL" =~ "zsh" ]] && shellrc="$HOME/.zshrc"
  grep -qxF "$content" "$shellrc" || echo "$content" >> "$shellrc"
}

# ──────────────────────────────────────────────────────────────── #
# 🚀 Start Setup
# ──────────────────────────────────────────────────────────────── #

print_banner

# Step 1: Update and install essentials
echo -e "${BLUE}🔧 Updating packages and installing essentials...${NC}"
sudo apt-get update -y && sudo apt-get install -y wget curl unzip build-essential jq

# Step 2: JAVA Setup (Eclipse Temurin)
echo -e "\n${CYAN}🧠 Java Setup${NC}"
prompt_input JDK_URL "Paste the JDK (Temurin) tar.gz link (or leave blank for latest):" ""

if [[ -z "$JDK_URL" ]]; then
  VERSION=$(curl -s https://api.adoptium.net/v3/info/release_names?image_type=jdk | jq -r '.[]' | grep hotspot | head -1)
  JDK_URL=$(curl -s "https://api.adoptium.net/v3/assets/latest/${VERSION//jdk-/}/ga?architecture=x64&heap_size=normal&image_type=jdk&os=linux" | jq -r '.[0].binary.package.link')
  echo -e "${GREEN}✅ Using latest JDK from Eclipse Temurin${NC}\n▶️ $JDK_URL"
else
  echo -e "${GREEN}✅ Using custom JDK link${NC}"
fi

echo -e "${BLUE}📦 Installing JDK...${NC}"
mkdir -p /opt/java
wget -qO /tmp/jdk.tar.gz "$JDK_URL"
sudo tar -xf /tmp/jdk.tar.gz -C /opt/java/
JAVA_DIR=$(find /opt/java -maxdepth 1 -type d -name "jdk*" | head -n 1)
add_to_shell_profile "export JAVA_HOME=$JAVA_DIR"
add_to_shell_profile 'export PATH=$JAVA_HOME/bin:$PATH'
export JAVA_HOME="$JAVA_DIR"
export PATH="$JAVA_HOME/bin:$PATH"

# Step 3: Android CLI Tools
echo -e "\n${CYAN}🤖 Android Command Line Tools Setup${NC}"
prompt_input ANDROID_URL "Paste Android Command Line Tools (Linux) zip link (or leave blank for latest):" ""

if [[ -z "$ANDROID_URL" ]]; then
  ANDROID_URL=$(curl -s https://developer.android.com/studio | grep -oP 'https://dl.google.com/android/repository/commandlinetools-linux-[^"]+' | head -1)
  echo -e "${GREEN}✅ Using latest Android CLI tools${NC}\n▶️ $ANDROID_URL"
else
  echo -e "${GREEN}✅ Using custom Android CLI tools link${NC}"
fi

ANDROID_HOME="$HOME/Android/Sdk"
mkdir -p "$ANDROID_HOME/cmdline-tools"
wget -qO /tmp/cli.zip "$ANDROID_URL"
unzip -qq /tmp/cli.zip -d "$ANDROID_HOME/cmdline-tools"
mv "$ANDROID_HOME/cmdline-tools/cmdline-tools" "$ANDROID_HOME/cmdline-tools/latest"

# Set Android Environment Vars
add_to_shell_profile "export ANDROID_HOME=$ANDROID_HOME"
add_to_shell_profile "export ANDROID_SDK_ROOT=$ANDROID_HOME"
add_to_shell_profile 'export PATH=$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH'
export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH"

# Step 4: Gradle Setup
echo -e "\n${CYAN}📦 Gradle Setup${NC}"
prompt_input GRADLE_VERSION "Enter Gradle version (or leave blank for latest):" ""
if [[ -z "$GRADLE_VERSION" ]]; then
  GRADLE_VERSION=$(curl -s https://services.gradle.org/versions/current | jq -r .version)
fi
GRADLE_ZIP="gradle-$GRADLE_VERSION-bin.zip"
GRADLE_URL="https://services.gradle.org/distributions/$GRADLE_ZIP"
echo -e "${GREEN}✅ Getting Gradle $GRADLE_VERSION${NC}"

wget -qO /tmp/$GRADLE_ZIP "$GRADLE_URL"
sudo unzip -qo /tmp/$GRADLE_ZIP -d /opt/gradle
add_to_shell_profile "export PATH=/opt/gradle/gradle-$GRADLE_VERSION/bin:\$PATH"
export PATH="/opt/gradle/gradle-$GRADLE_VERSION/bin:$PATH"

# Step 5: Android SDK packages
echo -e "\n${CYAN}📥 Installing Android SDK packages${NC}"
yes | sdkmanager --sdk_root="$ANDROID_HOME" "platform-tools" "platforms;android-34" "build-tools;34.0.0"
yes | sdkmanager --licenses

# Step 6: Done!
echo -e "\n${GREEN}✅ All set! Restart your terminal or source your profile:${NC}"
if [[ "$SHELL" =~ "zsh" ]]; then
  echo '    source ~/.zshrc'
else
  echo '    source ~/.bashrc'
fi

echo -e "\n${BLUE}🔍 Installed Tools:${NC}"
echo -e "${GREEN}▶ java -version${NC}"
java -version
echo -e "${GREEN}▶ gradle -v${NC}"
gradle -v
echo -e "${GREEN}▶ sdkmanager --version${NC}"
sdkmanager --version
