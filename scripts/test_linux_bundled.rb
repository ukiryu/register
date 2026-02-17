#!/usr/bin/env ruby
# frozen_string_literal: true

# Test which tools are bundled on which Linux distributions using Docker
# Usage: ruby scripts/test_linux_bundled.rb [options]
#
# Options:
#   --tools tool1,tool2    Comma-separated list of tools to test (default: all)
#   --output FILE          Output file for results (default: stdout)
#   --format FORMAT        Output format: json, yaml, markdown (default: markdown)
#   --verbose              Show verbose output

require "yaml"
require "json"
require "fileutils"

class LinuxBundledTester
  DISTRIBUTIONS = {
    "ubuntu" => {
      image: "ubuntu:24.04",
      package_manager: "apt",
      install_cmd: "apt-get update && apt-get install -y",
      check_cmd: "which"
    },
    "debian" => {
      image: "debian:bookworm",
      package_manager: "apt",
      install_cmd: "apt-get update && apt-get install -y",
      check_cmd: "which"
    },
    "alpine" => {
      image: "alpine:3.20",
      package_manager: "apk",
      install_cmd: "apk update && apk add",
      check_cmd: "which"
    },
    "fedora" => {
      image: "fedora:40",
      package_manager: "dnf",
      install_cmd: "dnf install -y",
      check_cmd: "which"
    },
    "arch" => {
      image: "archlinux:latest",
      package_manager: "pacman",
      install_cmd: "pacman -Sy --noconfirm",
      check_cmd: "which"
    }
  }.freeze

  # Tools to test for bundled status
  COMMON_TOOLS = %w[
    bash cat chmod chown cp curl cut date df diff dirname du echo env expr find
    grep gzip head hostname id ifconfig kill ln ls mkdir mv ping ps pwd rm
    rmdir sed sh sort ssh tar tee test touch tr uname uniq wc wget whoami xargs
    zip unzip scp rsync
  ].freeze

  def initialize(options = {})
    @verbose = options[:verbose] || false
    @tools = options[:tools] || COMMON_TOOLS
    @output_format = options[:format] || "markdown"
    @output_file = options[:output]
    @results = {}
  end

  def run
    puts "Testing bundled tools across Linux distributions..."
    puts "Distributions: #{DISTRIBUTIONS.keys.join(', ')}"
    puts "Tools to test: #{@tools.size} tools"
    puts

    DISTRIBUTIONS.each do |distro, config|
      test_distribution(distro, config)
    end

    output_results
  end

  private

  def test_distribution(distro, config)
    puts "=" * 60
    puts "Testing #{distro} (#{config[:image]})"
    puts "=" * 60

    @results[distro] = {
      image: config[:image],
      bundled: [],
      not_bundled: []
    }

    # Build a single command to check all tools
    check_cmds = @tools.map do |tool|
      "#{config[:check_cmd]} #{tool} >/dev/null 2>&1 && echo 'YES:#{tool}' || echo 'NO:#{tool}'"
    end

    # Run in Docker container
    cmd = [
      "docker", "run", "--rm",
      config[:image],
      "sh", "-c", check_cmds.join("; ")
    ]

    log "Running: #{cmd.join(' ')}"

    output = `#{cmd.join(" ")} 2>&1`
    log "Raw output:\n#{output}"

    # Parse results
    output.lines.each do |line|
      line = line.strip
      if line.start_with?("YES:")
        tool = line.sub("YES:", "")
        @results[distro][:bundled] << tool
        puts "  #{tool}: bundled"
      elsif line.start_with?("NO:")
        tool = line.sub("NO:", "")
        @results[distro][:not_bundled] << tool
        puts "  #{tool}: NOT bundled"
      end
    end

    puts
    puts "#{distro} summary: #{@results[distro][:bundled].size} bundled, #{@results[distro][:not_bundled].size} not bundled"
    puts
  end

  def output_results
    output = case @output_format
             when "json"
               format_json
             when "yaml"
               format_yaml
             else
               format_markdown
             end

    if @output_file
      File.write(@output_file, output)
      puts "Results written to #{@output_file}"
    else
      puts
      puts output
    end
  end

  def format_json
    JSON.pretty_generate(@results)
  end

  def format_yaml
    YAML.dump(@results)
  end

  def format_markdown
    lines = []
    lines << "# Linux Distribution Bundled Tools Report"
    lines << ""
    lines << "Generated: #{Time.now.utc}"
    lines << ""

    # Summary table
    lines << "## Summary"
    lines << ""
    lines << "| Distribution | Bundled | Not Bundled |"
    lines << "|-------------|---------|-------------|"
    @results.each do |distro, data|
      lines << "| #{distro} | #{data[:bundled].size} | #{data[:not_bundled].size} |"
    end
    lines << ""

    # Detailed results per distribution
    lines << "## Detailed Results"
    lines << ""

    @results.each do |distro, data|
      lines << "### #{distro}"
      lines << ""
      lines << "**Bundled tools:**"
      lines << ""
      if data[:bundled].any?
        data[:bundled].sort.each { |t| lines << "- #{t}" }
      else
        lines << "_None_"
      end
      lines << ""

      lines << "**Not bundled:**"
      lines << ""
      if data[:not_bundled].any?
        data[:not_bundled].sort.each { |t| lines << "- #{t}" }
      else
        lines << "_None_"
      end
      lines << ""
    end

    # Cross-distribution matrix
    lines << "## Cross-Distribution Matrix"
    lines << ""
    header = "| Tool | " + DISTRIBUTIONS.keys.join(" | ") + " |"
    lines << header
    lines << "|" + "-" * (header.length - 2) + "|"

    @tools.sort.each do |tool|
      row = ["#{tool}"]
      DISTRIBUTIONS.keys.each do |distro|
        bundled = @results[distro][:bundled].include?(tool)
        row << (bundled ? "yes" : "no")
      end
      lines << "| #{row.join(' | ')} |"
    end

    lines.join("\n")
  end

  def log(message)
    puts "[VERBOSE] #{message}" if @verbose
  end
end

# Parse command line options
options = {
  verbose: false,
  format: "markdown"
}

ARGV.each_with_index do |arg, idx|
  case arg
  when "--verbose"
    options[:verbose] = true
  when "--tools"
    options[:tools] = ARGV[idx + 1]&.split(",") || LinuxBundledTester::COMMON_TOOLS
  when "--output"
    options[:output] = ARGV[idx + 1]
  when "--format"
    options[:format] = ARGV[idx + 1] || "markdown"
  end
end

# Run the tester
tester = LinuxBundledTester.new(options)
tester.run
