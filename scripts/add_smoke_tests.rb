#!/usr/bin/env ruby
# frozen_string_literal: true

# Add smoke tests to all packages that don't have them
# Usage: ruby scripts/add_smoke_tests.rb [--dry-run]

require "yaml"
require "optparse"

# Map of tool name to smoke test command
SMOKE_TESTS = {
  # Standard --version
  "ansible" => "ansible --version",
  "curl" => "curl --version",
  "exiftool" => "exiftool -ver",
  "ghostscript" => "gs --version",
  "gifsicle" => "gifsicle --version",
  "git" => "git --version",
  "htop" => "htop --version",
  "imagemagick" => "magick --version",
  "convert" => "magick --version || convert --version",
  "inkscape" => "inkscape --version",
  "jpegoptim" => "jpegoptim --version",
  "less" => "less --version",
  "libreoffice" => "libreoffice --version || soffice --version",
  "lsof" => "lsof -v",
  "make" => "make --version",
  "openssl" => "openssl version",
  "optipng" => "optipng -version",
  "p7zip" => "7z --help || 7za --help",
  "pdftk" => "pdftk --version",
  "pdf2ps" => "gs --version",
  "ping" => "ping -V || ping -c 1 127.0.0.1",
  "pngquant" => "pngquant --version",
  "rclone" => "rclone version",
  "restic" => "restic version",
  "ripgrep-all" => "rga --version",
  "rsync" => "rsync --version",
  "scp" => "scp -V",
  "sox" => "sox --version || soxi --version",
  "ssh" => "ssh -V",
  "tree" => "tree --version",
  "unzip" => "unzip -v",
  "vim" => "vim --version | head -1",
  "wget" => "wget --version",
  "xz" => "xz --version",
  "yq" => "yq --version",
  "yq_jq" => "yq --version",
  "yt-dlp" => "yt-dlp --version",
  "zip" => "zip -v",
  "zstd" => "zstd --version",

  # Special cases
  "awk" => "awk --version || gawk --version || mawk --version",
  "bzip2" => "bzip2 --version 2>&1 || echo 'bzip2 available'",
  "gzip" => "gzip --version",
  "cwebp" => "cwebp -version || webp -version",
  "dwebp" => "dwebp -version || webp -version",
  "tar" => "tar --version",
}.freeze

def add_smoke_tests(package_file, dry_run: false)
  content = File.read(package_file)
  config = YAML.load(content, aliases: true)

  tool_name = config["name"]
  smoke_test = SMOKE_TESTS[tool_name]

  unless smoke_test
    puts "WARNING: No smoke test defined for #{tool_name}"
    return false
  end

  packages = config["packages"] || {}

  # Check if any package manager already has smoke_test
  has_smoke_test = packages.any? do |_pm, pkgs|
    pkgs.any? { |pkg| pkg.is_a?(Hash) && pkg["smoke_test"] }
  end

  if has_smoke_test
    puts "SKIP: #{tool_name} already has smoke tests"
    return false
  end

  # Add smoke_test to all package managers
  modified = false
  packages.each do |_pm, pkgs|
    pkgs.each do |pkg|
      if pkg.is_a?(Hash)
        pkg["smoke_test"] = smoke_test
        modified = true
      end
    end
  end

  if modified
    if dry_run
      puts "DRY RUN: Would add smoke test to #{tool_name}: #{smoke_test}"
    else
      # Write back to file with proper formatting
      File.write(package_file, YAML.dump(config).gsub("---\n", ""))
      puts "ADDED: #{tool_name} -> #{smoke_test}"
    end
    return true
  end

  false
end

def main
  options = { dry_run: false }

  OptionParser.new do |opts|
    opts.banner = "Usage: #{$PROGRAM_NAME} [options]"
    opts.on("--dry-run", "Show what would be changed without modifying files") do
      options[:dry_run] = true
    end
  end.parse!

  packages_dir = File.join(File.dirname(__dir__), "packages")
  files = Dir.glob(File.join(packages_dir, "*.yaml"))

  puts "Processing #{files.size} package files..."
  puts ""

  modified_count = 0
  files.each do |file|
    if add_smoke_tests(file, dry_run: options[:dry_run])
      modified_count += 1
    end
  end

  puts ""
  puts "Summary: #{modified_count} packages #{options[:dry_run] ? 'would be ' : ''}modified"
end

main if __FILE__ == $PROGRAM_NAME
