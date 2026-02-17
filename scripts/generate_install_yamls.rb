#!/usr/bin/env ruby
# frozen_string_literal: true

# Generate install.yaml files for ukiryu tools using x-cmd data

require "json"
require "yaml"
require "fileutils"

REGISTER_ROOT = File.expand_path("..", __dir__)
XCMD_DATA_DIR = File.join(REGISTER_ROOT, ".x-cmd-data", "pkg", "v0.1.2", "install")
TOOLS_DIR = File.join(REGISTER_ROOT, "tools")

# Package managers we support
PACKAGE_MANAGERS = %w[
  homebrew
  macports
  apt
  dnf
  yum
  apk
  pacman
  chocolatey
  winget
].freeze

# Map x-cmd platform keys to our package manager names
XCMD_PLATFORM_MAP = {
  "darwin/brew" => "homebrew",
  "brew" => "homebrew",
  "ubuntu/apt" => "apt",
  "debian/apt" => "apt",
  "debian//apt" => "apt",
  "kali/apt" => "apt",
  "kali//apt" => "apt",
  "raspbian/apt" => "apt",
  "fedora/dnf" => "dnf",
  "alpine/apk" => "apk",
  "arch/pacman" => "pacman",
  "win/powershell" => "winget",
  "win/winget" => "winget",
  "win/choco" => "chocolatey",
  "/choco" => "chocolatey",
}.freeze

# Common package name mappings (tool name -> package name per manager)
# These are used as fallbacks when x-cmd data is not available
KNOWN_PACKAGES = {
  "imagemagick" => {
    "homebrew" => ["imagemagick"],
    "macports" => ["ImageMagick"],
    "apt" => ["imagemagick"],
    "dnf" => ["ImageMagick"],
    "yum" => ["ImageMagick"],
    "apk" => ["imagemagick"],
    "pacman" => ["imagemagick"],
    "chocolatey" => ["imagemagick"],
    "winget" => ["ImageMagick.ImageMagick"],
  },
  "ffmpeg" => {
    "homebrew" => ["ffmpeg"],
    "macports" => ["ffmpeg"],
    "apt" => ["ffmpeg"],
    "dnf" => ["ffmpeg"],
    "yum" => ["ffmpeg"],
    "apk" => ["ffmpeg"],
    "pacman" => ["ffmpeg"],
    "chocolatey" => ["ffmpeg"],
    "winget" => ["Gyan.FFmpeg"],
  },
  "pandoc" => {
    "homebrew" => ["pandoc"],
    "macports" => ["pandoc"],
    "apt" => ["pandoc"],
    "dnf" => ["pandoc"],
    "yum" => ["pandoc"],
    "apk" => ["pandoc"],
    "pacman" => ["pandoc"],
    "chocolatey" => ["pandoc"],
    "winget" => ["JohnMacFarlane.Pandoc"],
  },
  "git" => {
    "homebrew" => ["git"],
    "macports" => ["git"],
    "apt" => ["git"],
    "dnf" => ["git"],
    "yum" => ["git"],
    "apk" => ["git"],
    "pacman" => ["git"],
    "chocolatey" => ["git"],
    "winget" => ["Git.Git"],
  },
  "curl" => {
    "homebrew" => ["curl"],
    "macports" => ["curl"],
    "apt" => ["curl"],
    "dnf" => ["curl"],
    "yum" => ["curl"],
    "apk" => ["curl"],
    "pacman" => ["curl"],
    "chocolatey" => ["curl"],
    "winget" => ["curl.curl"],
  },
  "wget" => {
    "homebrew" => ["wget"],
    "macports" => ["wget"],
    "apt" => ["wget"],
    "dnf" => ["wget"],
    "yum" => ["wget"],
    "apk" => ["wget"],
    "pacman" => ["wget"],
    "chocolatey" => ["wget"],
    "winget" => ["GNU.Wget"],
  },
  "jq" => {
    "homebrew" => ["jq"],
    "macports" => ["jq"],
    "apt" => ["jq"],
    "dnf" => ["jq"],
    "yum" => ["jq"],
    "apk" => ["jq"],
    "pacman" => ["jq"],
    "chocolatey" => ["jq"],
    "winget" => ["jqlang.jq"],
  },
  "yq" => {
    "homebrew" => ["yq"],
    "macports" => ["yq"],
    "apt" => ["yq"],
    "dnf" => ["yq"],
    "yum" => ["yq"],
    "apk" => ["yq"],
    "pacman" => ["yq"],
    "chocolatey" => ["yq"],
    "winget" => ["MikeFarah.yq"],
  },
  "ripgrep" => {
    "homebrew" => ["ripgrep"],
    "macports" => ["ripgrep"],
    "apt" => ["ripgrep"],
    "dnf" => ["ripgrep"],
    "yum" => ["ripgrep"],
    "apk" => ["ripgrep"],
    "pacman" => ["ripgrep"],
    "chocolatey" => ["ripgrep"],
    "winget" => ["BurntSushi.ripgrep.MSVC"],
  },
  "fd" => {
    "homebrew" => ["fd"],
    "macports" => ["fd"],
    "apt" => ["fd-find"],
    "dnf" => ["fd-find"],
    "yum" => ["fd-find"],
    "apk" => ["fd"],
    "pacman" => ["fd"],
    "chocolatey" => ["fd"],
    "winget" => ["sharkdp.fd"],
  },
  "fzf" => {
    "homebrew" => ["fzf"],
    "macports" => ["fzf"],
    "apt" => ["fzf"],
    "dnf" => ["fzf"],
    "yum" => ["fzf"],
    "apk" => ["fzf"],
    "pacman" => ["fzf"],
    "chocolatey" => ["fzf"],
    "winget" => ["junegunn.fzf"],
  },
  "bat" => {
    "homebrew" => ["bat"],
    "macports" => ["bat"],
    "apt" => ["bat"],
    "dnf" => ["bat"],
    "yum" => ["bat"],
    "apk" => ["bat"],
    "pacman" => ["bat"],
    "chocolatey" => ["bat"],
    "winget" => ["sharkdp.bat"],
  },
  "tree" => {
    "homebrew" => ["tree"],
    "macports" => ["tree"],
    "apt" => ["tree"],
    "dnf" => ["tree"],
    "yum" => ["tree"],
    "apk" => ["tree"],
    "pacman" => ["tree"],
    "chocolatey" => ["tree"],
    "winget" => ["GnuWin32.Tree"],
  },
  "htop" => {
    "homebrew" => ["htop"],
    "macports" => ["htop"],
    "apt" => ["htop"],
    "dnf" => ["htop"],
    "yum" => ["htop"],
    "apk" => ["htop"],
    "pacman" => ["htop"],
    "chocolatey" => ["htop"],
    "winget" => ["htop.htop"],
  },
  "vim" => {
    "homebrew" => ["vim"],
    "macports" => ["vim"],
    "apt" => ["vim"],
    "dnf" => ["vim-enhanced"],
    "yum" => ["vim-enhanced"],
    "apk" => ["vim"],
    "pacman" => ["vim"],
    "chocolatey" => ["vim"],
    "winget" => ["vim.vim"],
  },
  "rsync" => {
    "homebrew" => ["rsync"],
    "macports" => ["rsync"],
    "apt" => ["rsync"],
    "dnf" => ["rsync"],
    "yum" => ["rsync"],
    "apk" => ["rsync"],
    "pacman" => ["rsync"],
    "chocolatey" => ["rsync"],
    "winget" => ["WayneD/rsync"],
  },
  "tar" => {
    "homebrew" => ["gnu-tar"],
    "macports" => ["gnutar"],
    "apt" => ["tar"],
    "dnf" => ["tar"],
    "yum" => ["tar"],
    "apk" => ["tar"],
    "pacman" => ["tar"],
    "chocolatey" => ["msys2"],
    "winget" => ["MSYS2.MSYS2"],
  },
  "zip" => {
    "homebrew" => ["zip"],
    "macports" => ["zip"],
    "apt" => ["zip"],
    "dnf" => ["zip"],
    "yum" => ["zip"],
    "apk" => ["zip"],
    "pacman" => ["zip"],
    "chocolatey" => ["zip"],
    "winget" => ["7zip.7zip"],
  },
  "unzip" => {
    "homebrew" => ["unzip"],
    "macports" => ["unzip"],
    "apt" => ["unzip"],
    "dnf" => ["unzip"],
    "yum" => ["unzip"],
    "apk" => ["unzip"],
    "pacman" => ["unzip"],
    "chocolatey" => ["unzip"],
    "winget" => ["7zip.7zip"],
  },
  "p7zip" => {
    "homebrew" => ["p7zip"],
    "macports" => ["p7zip"],
    "apt" => ["p7zip-full"],
    "dnf" => ["p7zip"],
    "yum" => ["p7zip"],
    "apk" => ["p7zip"],
    "pacman" => ["p7zip"],
    "chocolatey" => ["7zip"],
    "winget" => ["7zip.7zip"],
  },
  "zstd" => {
    "homebrew" => ["zstd"],
    "macports" => ["zstd"],
    "apt" => ["zstd"],
    "dnf" => ["zstd"],
    "yum" => ["zstd"],
    "apk" => ["zstd"],
    "pacman" => ["zstd"],
    "chocolatey" => ["zstd"],
    "winget" => ["facebook.zstd"],
  },
  "xz" => {
    "homebrew" => ["xz"],
    "macports" => ["xz"],
    "apt" => ["xz-utils"],
    "dnf" => ["xz"],
    "yum" => ["xz"],
    "apk" => ["xz"],
    "pacman" => ["xz"],
    "chocolatey" => ["7zip"],
    "winget" => ["7zip.7zip"],
  },
  "bzip2" => {
    "homebrew" => ["bzip2"],
    "macports" => ["bzip2"],
    "apt" => ["bzip2"],
    "dnf" => ["bzip2"],
    "yum" => ["bzip2"],
    "apk" => ["bzip2"],
    "pacman" => ["bzip2"],
    "chocolatey" => ["bzip2"],
    "winget" => ["7zip.7zip"],
  },
  "gzip" => {
    "homebrew" => ["gzip"],
    "macports" => ["gzip"],
    "apt" => ["gzip"],
    "dnf" => ["gzip"],
    "yum" => ["gzip"],
    "apk" => ["gzip"],
    "pacman" => ["gzip"],
    "chocolatey" => ["gzip"],
    "winget" => ["7zip.7zip"],
  },
  "ansible" => {
    "homebrew" => ["ansible"],
    "macports" => ["ansible"],
    "apt" => ["ansible"],
    "dnf" => ["ansible"],
    "yum" => ["ansible"],
    "apk" => ["ansible"],
    "pacman" => ["ansible"],
    "chocolatey" => ["ansible"],
    "winget" => ["Ansible.Ansible"],
  },
  "exiftool" => {
    "homebrew" => ["exiftool"],
    "macports" => ["p5-image-exiftool"],
    "apt" => ["libimage-exiftool-perl"],
    "dnf" => ["perl-Image-ExifTool"],
    "yum" => ["perl-Image-ExifTool"],
    "apk" => ["exiftool"],
    "pacman" => ["perl-image-exiftool"],
    "chocolatey" => ["exiftool"],
    "winget" => ["OliverBetz.ExifTool"],
  },
  "libreoffice" => {
    "homebrew" => ["libreoffice"],
    "macports" => ["libreoffice"],
    "apt" => ["libreoffice"],
    "dnf" => ["libreoffice"],
    "yum" => ["libreoffice"],
    "apk" => ["libreoffice"],
    "pacman" => ["libreoffice-fresh"],
    "chocolatey" => ["libreoffice-fresh"],
    "winget" => ["TheDocumentFoundation.LibreOffice"],
  },
  "inkscape" => {
    "homebrew" => ["inkscape"],
    "macports" => ["inkscape"],
    "apt" => ["inkscape"],
    "dnf" => ["inkscape"],
    "yum" => ["inkscape"],
    "apk" => ["inkscape"],
    "pacman" => ["inkscape"],
    "chocolatey" => ["inkscape"],
    "winget" => ["Inkscape.Inkscape"],
  },
  "ghostscript" => {
    "homebrew" => ["ghostscript"],
    "macports" => ["ghostscript"],
    "apt" => ["ghostscript"],
    "dnf" => ["ghostscript"],
    "yum" => ["ghostscript"],
    "apk" => ["ghostscript"],
    "pacman" => ["ghostscript"],
    "chocolatey" => ["ghostscript"],
    "winget" => ["ArtifexSoftware.GhostScript"],
  },
  "pdftk" => {
    "homebrew" => ["pdftk-java"],
    "macports" => ["pdftk"],
    "apt" => ["pdftk-java"],
    "dnf" => ["pdftk"],
    "yum" => ["pdftk"],
    "apk" => ["pdftk"],
    "pacman" => ["pdftk"],
    "chocolatey" => ["pdftk"],
    "winget" => ["PDFtk.PDFtk"],
  },
  "openssl" => {
    "homebrew" => ["openssl"],
    "macports" => ["openssl"],
    "apt" => ["openssl"],
    "dnf" => ["openssl"],
    "yum" => ["openssl"],
    "apk" => ["openssl"],
    "pacman" => ["openssl"],
    "chocolatey" => ["openssl"],
    "winget" => ["ShiningLight.OpenSSL"],
  },
  "sox" => {
    "homebrew" => ["sox"],
    "macports" => ["sox"],
    "apt" => ["sox"],
    "dnf" => ["sox"],
    "yum" => ["sox"],
    "apk" => ["sox"],
    "pacman" => ["sox"],
    "chocolatey" => ["sox"],
    "winget" => ["sox"],
  },
  "gifsicle" => {
    "homebrew" => ["gifsicle"],
    "macports" => ["gifsicle"],
    "apt" => ["gifsicle"],
    "dnf" => ["gifsicle"],
    "yum" => ["gifsicle"],
    "apk" => ["gifsicle"],
    "pacman" => ["gifsicle"],
    "chocolatey" => ["gifsicle"],
    "winget" => ["gifsicle"],
  },
  "rclone" => {
    "homebrew" => ["rclone"],
    "macports" => ["rclone"],
    "apt" => ["rclone"],
    "dnf" => ["rclone"],
    "yum" => ["rclone"],
    "apk" => ["rclone"],
    "pacman" => ["rclone"],
    "chocolatey" => ["rclone"],
    "winget" => ["Rclone.Rclone"],
  },
  "restic" => {
    "homebrew" => ["restic"],
    "macports" => ["restic"],
    "apt" => ["restic"],
    "dnf" => ["restic"],
    "yum" => ["restic"],
    "apk" => ["restic"],
    "pacman" => ["restic"],
    "chocolatey" => ["restic"],
    "winget" => ["restic.restic"],
  },
  "yt-dlp" => {
    "homebrew" => ["yt-dlp"],
    "macports" => ["yt-dlp"],
    "apt" => ["yt-dlp"],
    "dnf" => ["yt-dlp"],
    "yum" => ["yt-dlp"],
    "apk" => ["yt-dlp"],
    "pacman" => ["yt-dlp"],
    "chocolatey" => ["yt-dlp"],
    "winget" => ["yt-dlp.yt-dlp"],
  },
  "make" => {
    "homebrew" => ["make"],
    "macports" => ["gmake"],
    "apt" => ["make"],
    "dnf" => ["make"],
    "yum" => ["make"],
    "apk" => ["make"],
    "pacman" => ["make"],
    "chocolatey" => ["make"],
    "winget" => ["GnuWin32.Make"],
  },
  "lsof" => {
    "homebrew" => ["lsof"],
    "macports" => ["lsof"],
    "apt" => ["lsof"],
    "dnf" => ["lsof"],
    "yum" => ["lsof"],
    "apk" => ["lsof"],
    "pacman" => ["lsof"],
    "chocolatey" => ["sysinternals"],
    "winget" => ["Microsoft.Sysinternals.ProcessExplorer"],
  },
  "less" => {
    "homebrew" => ["less"],
    "macports" => ["less"],
    "apt" => ["less"],
    "dnf" => ["less"],
    "yum" => ["less"],
    "apk" => ["less"],
    "pacman" => ["less"],
    "chocolatey" => ["less"],
    "winget" => ["jftuga.less"],
  },
}.freeze

# System tools that don't need install.yaml (pre-installed everywhere)
SYSTEM_TOOLS = %w[
  cat
  cut
  diff
  grep
  head
  sort
  tail
  tee
  wc
  xargs
  sed
  find
  ssh
  scp
  ping
].freeze

def load_tsv_data
  data = {}

  %w[ubuntu-apt debian-apt kali-apt fedora-dnf alpine-apk].each do |file|
    path = File.join(XCMD_DATA_DIR, ".x-cmd", "#{file}.tsv")
    next unless File.exist?(path)

    manager = case file
              when /apt$/ then "apt"
              when /dnf$/ then "dnf"
              when /apk$/ then "apk"
              end

    data[manager] ||= {}

    File.readlines(path).each do |line|
      line.strip!
      next if line.empty?

      parts = line.split("\t")
      next unless parts.length >= 2

      package = parts[0].strip
      command = parts[1].strip

      # Skip lines that look like commands (start with spaces or special chars)
      next if package.start_with?(" ") || package.start_with?("-")

      # Use the first mapping (ubuntu-apt takes precedence)
      data[manager][command] ||= package
    end
  end

  data
end

def load_json_data
  data = {}

  Dir.glob(File.join(XCMD_DATA_DIR, "*", "*.json")).each do |json_path|
    begin
      content = JSON.parse(File.read(json_path))
      tool_name = File.basename(json_path, ".json")

      next unless content["rule"]

      content["rule"].each do |platform, rule_info|
        pm = XCMD_PLATFORM_MAP[platform]
        next unless pm
        next unless rule_info.is_a?(Hash)

        data[tool_name] ||= {}
        data[tool_name][pm] ||= []

        # Extract package name from command
        cmd = rule_info["cmd"] || ""
        case pm
        when "homebrew"
          if cmd =~ /brew install (.+)$/
            data[tool_name][pm] = $1.split
          end
        when "apt"
          if cmd =~ /apt(?:-get)? install (?:-y\s+)?(.+)$/
            data[tool_name][pm] = $1.split
          end
        when "dnf"
          if cmd =~ /dnf install (?:-y\s+)?(.+)$/
            data[tool_name][pm] = $1.split
          end
        when "apk"
          if cmd =~ /apk add (.+)$/
            data[tool_name][pm] = $1.split
          end
        when "pacman"
          if cmd =~ /pacman -S (.+)$/
            data[tool_name][pm] = $1.split
          end
        when "chocolatey"
          if cmd =~ /choco install (.+)$/
            data[tool_name][pm] = $1.split
          end
        when "winget"
          if cmd =~ /winget install (.+)$/
            data[tool_name][pm] = $1.split
          end
        end
      end
    rescue JSON::ParserError
      next
    end
  end

  data
end

def generate_install_yaml(tool_name, packages)
  return nil if packages.nil? || packages.empty?

  yaml = {
    "ukiryu_schema" => "1.0",
    "name" => tool_name,
    "packages" => {},
  }

  PACKAGE_MANAGERS.each do |pm|
    if packages[pm] && !packages[pm].empty?
      yaml["packages"][pm] = packages[pm].is_a?(Array) ? packages[pm] : [packages[pm]]
    end
  end

  yaml["packages"].empty? ? nil : yaml
end

def main
  puts "Loading x-cmd TSV data..."
  tsv_data = load_tsv_data
  puts "  apt: #{tsv_data['apt']&.size || 0} packages"
  puts "  dnf: #{tsv_data['dnf']&.size || 0} packages"
  puts "  apk: #{tsv_data['apk']&.size || 0} packages"

  puts "\nLoading x-cmd JSON data..."
  json_data = load_json_data
  puts "  #{json_data.size} tools with platform rules"

  puts "\nGenerating install.yaml files..."

  Dir.glob(File.join(TOOLS_DIR, "*")).each do |tool_dir|
    next unless File.directory?(tool_dir)

    tool_name = File.basename(tool_dir)

    # Skip system tools
    if SYSTEM_TOOLS.include?(tool_name)
      puts "  [SKIP] #{tool_name} (system tool)"
      next
    end

    # Find the executable name(s) for this tool
    # Check the tool profile for executables
    executables = find_executables_for_tool(tool_dir)
    executables = [tool_name] if executables.empty?

    # Collect packages from all sources
    packages = {}

    # 1. Use known packages first (most reliable)
    if KNOWN_PACKAGES[tool_name]
      packages = KNOWN_PACKAGES[tool_name].dup
    else
      # 2. Try to find from TSV data
      executables.each do |exe|
        %w[apt dnf apk].each do |pm|
          next if packages[pm]

          pkg = tsv_data[pm]&.dig(exe)
          packages[pm] = [pkg] if pkg
        end
      end

      # 3. Try to find from JSON data
      executables.each do |exe|
        json_data[exe]&.each do |pm, pkgs|
          next if packages[pm]
          packages[pm] = pkgs if pkgs && !pkgs.empty?
        end
      end

      # 4. Also try the tool name directly
      json_data[tool_name]&.each do |pm, pkgs|
        packages[pm] ||= pkgs if pkgs && !pkgs.empty?
      end
    end

    # Generate YAML
    yaml_content = generate_install_yaml(tool_name, packages)

    if yaml_content
      output_path = File.join(tool_dir, "install.yaml")
      File.write(output_path, yaml_content.to_yaml.gsub("---\n", ""))
      puts "  [CREATED] #{tool_name}/install.yaml"
    else
      puts "  [NO DATA] #{tool_name} - no package mappings found"
    end
  end
end

def find_executables_for_tool(tool_dir)
  executables = []

  # Check index.yaml for executable names
  index_path = File.join(tool_dir, "index.yaml")
  if File.exist?(index_path)
    begin
      content = YAML.load_file(index_path)
      if content["implementations"]
        content["implementations"].each do |impl|
          if impl["detection"] && impl["detection"]["executables"]
            executables.concat(impl["detection"]["executables"])
          end
        end
      end
    rescue StandardError
      # Ignore parse errors
    end
  end

  # Check version files for version_detection
  Dir.glob(File.join(tool_dir, "*.yaml")).each do |yaml_file|
    next if File.basename(yaml_file) == "index.yaml"

    begin
      content = YAML.load_file(yaml_file)
      if content["aliases"]
        executables.concat(content["aliases"])
      end
    rescue StandardError
      # Ignore parse errors
    end
  end

  executables.uniq
end

main if __FILE__ == $PROGRAM_NAME
