#!/usr/bin/env ruby
# frozen_string_literal: true

# Test which tools are bundled on different Linux distributions using Docker
# Usage: ruby scripts/test_bundled_tools.rb [--tools "tar,curl,ssh"]

require "yaml"
require "json"
require "optparse"

# Docker images for each distro
DISTROS = {
  "ubuntu" => "ubuntu:24.04",
  "debian" => "debian:bookworm",
  "alpine" => "alpine:latest",
  "fedora" => "fedora:latest",
  "arch" => "archlinux:latest",
}.freeze

# Tools to check
DEFAULT_TOOLS = %w[
  tar curl wget ping ssh scp gzip bzip2 zip unzip
  make vim less tree htop rsync openssl jq yq
  git ffmpeg magick convert pandoc
].freeze

def check_tool_in_docker(image, tool)
  cmd = "docker run --rm #{image} which #{tool} 2>/dev/null"
  result = `#{cmd}`.strip
  !result.empty?
end

def test_all_distros(tools)
  results = {}

  DISTROS.each do |distro_name, image|
    puts "Testing #{distro_name} (#{image})..."
    results[distro_name] = {}

    tools.each do |tool|
      bundled = check_tool_in_docker(image, tool)
      results[distro_name][tool] = bundled
      status = bundled ? "✓ BUNDLED" : "✗ NOT BUNDLED"
      puts "  #{tool}: #{status}"
    end
    puts ""
  end

  results
end

def generate_report(results, tools)
  puts "=" * 60
  puts "SUMMARY: Which tools are bundled on which platform"
  puts "=" * 60
  puts ""

  # Header
  header = "Tool".ljust(15)
  DISTROS.each_key { |d| header += d.ljust(10) }
  puts header
  puts "-" * header.length

  # Rows
  tools.each do |tool|
    row = tool.ljust(15)
    DISTROS.each_key do |distro|
      bundled = results[distro][tool]
      row += bundled ? "✓".ljust(10) : "✗".ljust(10)
    end
    puts row
  end

  puts ""
  puts "Legend: ✓ = bundled, ✗ = needs installation"
end

def generate_yaml_snippet(results, tools)
  puts ""
  puts "=" * 60
  puts "YAML platforms snippet for each tool"
  puts "=" * 60
  puts ""

  tools.each do |tool|
    bundled_distros = DISTROS.keys.select { |d| results[d][tool] }
    non_bundled_distros = DISTROS.keys.reject { |d| results[d][tool] }

    puts "# #{tool}"
    puts "platforms:"
    bundled_distros.each do |d|
      puts "  #{d}:"
      puts "    bundled: true"
    end
    non_bundled_distros.each do |d|
      puts "  #{d}:"
      puts "    bundled: false"
    end
    puts ""
  end
end

def main
  options = { tools: DEFAULT_TOOLS }

  OptionParser.new do |opts|
    opts.banner = "Usage: #{$PROGRAM_NAME} [options]"
    opts.on("--tools LIST", "Comma-separated list of tools to check") do |list|
      options[:tools] = list.split(",").map(&:strip)
    end
    opts.on("--yaml", "Generate YAML snippet for each tool") do
      options[:yaml] = true
    end
  end.parse!

  puts "Checking #{options[:tools].size} tools across #{DISTROS.size} distros..."
  puts ""

  results = test_all_distros(options[:tools])
  generate_report(results, options[:tools])

  generate_yaml_snippet(results, options[:tools]) if options[:yaml]
end

main if __FILE__ == $PROGRAM_NAME
