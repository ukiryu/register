#!/usr/bin/env ruby
# frozen_string_literal: true

# Detect coverage gaps between tool profiles and package availability
#
# A coverage gap exists when:
# - A tool profile claims to support a platform
# - But the package file has no entry for that platform's package manager

require "yaml"
require "optparse"

# Platform to required package managers mapping
# At least ONE of the package managers must be defined for full coverage
PLATFORM_PACKAGE_MANAGERS = {
  "macos" => %w[homebrew macports],
  "linux" => %w[apt dnf yum apk pacman],  # At least one Linux PM
  "windows" => %w[chocolatey winget],
}.freeze

# More specific Linux mappings
LINUX_PM_MAP = {
  "apt" => %w[ubuntu debian kali],
  "dnf" => %w[fedora],
  "yum" => %w[rhel centos almalinux rocky],
  "apk" => %w[alpine],
  "pacman" => %w[arch manjaro],
}.freeze

# Tools that are pre-installed on ALL platforms (no package needed)
SYSTEM_TOOLS = %w[
  cat
  cut
  diff
  find
  grep
  head
  sed
  sort
  tail
  tee
  wc
  xargs
].freeze

# Tools that are built into specific platforms (no package needed)
# Format: { tool => [platforms where it's built-in] }
OS_BUNDLED_TOOLS = {
  "ping" => %w[macos windows],  # Only needs package on minimal Linux
  "ssh" => %w[macos windows],   # Built into macOS and Windows 10+
  "scp" => %w[macos windows],   # Built into macOS and Windows 10+
  "ukiryu" => %w[macos linux windows],  # Framework, installed via RubyGems
}.freeze

# Tools that are only available via pip/non-system package managers
# These gaps are expected and cannot be filled with system package managers
PIP_ONLY_TOOLS = %w[
  yq_jq  # kislyuk/yq - only available as system package on apt
].freeze

class CoverageGapDetector
  def initialize(options = {})
    @register_path = options[:register] || detect_register_path
    @verbose = options[:verbose] || false
    @gaps = []
    @tools_dir = File.join(@register_path, "tools")
    @packages_dir = File.join(@register_path, "packages")
  end

  def run
    puts "Coverage Gap Analysis"
    puts "====================="
    puts ""

    # Get all tools
    tools = Dir.glob(File.join(@tools_dir, "*"))
               .select { |f| File.directory?(f) }
               .map { |f| File.basename(f) }

    puts "Analyzing #{tools.size} tools..."
    puts ""

    tools.each do |tool_name|
      analyze_tool(tool_name)
    end

    report_results
  end

  private

  def detect_register_path
    ENV["UKIRYU_REGISTER"] || Dir.pwd
  end

  def analyze_tool(tool_name)
    # Skip system tools (pre-installed everywhere)
    if SYSTEM_TOOLS.include?(tool_name)
      puts "  [SKIP] #{tool_name} (system tool)" if @verbose
      return
    end

    # Skip tools that are only available via pip
    if PIP_ONLY_TOOLS.include?(tool_name)
      puts "  [SKIP] #{tool_name} (pip-only, not available via system PM)" if @verbose
      return
    end

    # Get supported platforms from tool profile
    supported_platforms = get_supported_platforms(tool_name)
    return if supported_platforms.empty?

    # Get available package managers from packages/*.yaml
    available_pms = get_available_package_managers(tool_name)

    # Check for gaps
    supported_platforms.each do |platform|
      # Skip if tool is OS-bundled on this platform
      if OS_BUNDLED_TOOLS[tool_name]&.include?(platform)
        puts "  [SKIP] #{tool_name} on #{platform} (OS-bundled)" if @verbose
        next
      end

      required_pms = PLATFORM_PACKAGE_MANAGERS[platform]
      next unless required_pms

      has_coverage = required_pms.any? { |pm| available_pms.include?(pm) }

      unless has_coverage
        @gaps << {
          tool: tool_name,
          platform: platform,
          required_pms: required_pms,
          available_pms: available_pms,
        }
      end
    end
  end

  def get_supported_platforms(tool_name)
    platforms = Set.new

    # Check index.yaml
    index_path = File.join(@tools_dir, tool_name, "index.yaml")
    if File.exist?(index_path)
      platforms.merge(extract_platforms_from_yaml(index_path))
    end

    # Check version files
    Dir.glob(File.join(@tools_dir, tool_name, "*.yaml")).each do |yaml_file|
      next if File.basename(yaml_file) == "index.yaml"
      platforms.merge(extract_platforms_from_yaml(yaml_file))
    end

    # Check implementation subdirectories
    Dir.glob(File.join(@tools_dir, tool_name, "*/")).each do |subdir|
      impl_name = File.basename(subdir)
      Dir.glob(File.join(subdir, "*.yaml")).each do |yaml_file|
        platforms.merge(extract_platforms_from_yaml(yaml_file))
      end
    end

    platforms.to_a
  end

  def extract_platforms_from_yaml(yaml_path)
    platforms = Set.new

    begin
      content = YAML.load_file(yaml_path)
      return platforms.to_a unless content.is_a?(Hash)

      # Check profiles array
      if content["profiles"]
        content["profiles"].each do |profile|
          if profile["platforms"]
            platforms.merge(profile["platforms"])
          end
        end
      end

      # Check implementations (for index.yaml)
      if content["implementations"]
        content["implementations"].each do |impl|
          # Default implementations support what the profile supports
          platforms << "macos" << "linux" << "windows"
        end
      end
    rescue StandardError => e
      puts "Warning: Failed to parse #{yaml_path}: #{e.message}" if @verbose
    end

    platforms.to_a
  end

  def get_available_package_managers(tool_name)
    package_file = File.join(@packages_dir, "#{tool_name}.yaml")
    return [] unless File.exist?(package_file)

    begin
      content = YAML.load_file(package_file)
      return [] unless content.is_a?(Hash) && content["packages"]

      content["packages"].keys
    rescue StandardError => e
      puts "Warning: Failed to parse #{package_file}: #{e.message}" if @verbose
      []
    end
  end

  def report_results
    if @gaps.empty?
      puts "✅ No coverage gaps found!"
      puts "All tools have packages defined for their supported platforms."
      return
    end

    puts "❌ Found #{@gaps.size} coverage gaps:"
    puts ""

    # Group by tool
    gaps_by_tool = @gaps.group_by { |g| g[:tool] }

    gaps_by_tool.each do |tool, gaps|
      puts "#{tool}:"
      gaps.each do |gap|
        puts "  - Missing for #{gap[:platform]}"
        puts "    Required: #{gap[:required_pms].join(', ')}"
        puts "    Available: #{gap[:available_pms].empty? ? 'none' : gap[:available_pms].join(', ')}"
      end
      puts ""
    end

    # Summary by platform
    puts ""
    puts "Summary by Platform:"
    puts "--------------------"

    gaps_by_platform = @gaps.group_by { |g| g[:platform] }
    gaps_by_platform.each do |platform, gaps|
      tools = gaps.map { |g| g[:tool] }.sort
      puts "#{platform}: #{gaps.size} tools missing packages"
      puts "  #{tools.join(', ')}"
    end
  end
end

# Main
if __FILE__ == $PROGRAM_NAME
  options = {}

  OptionParser.new do |opts|
    opts.banner = "Usage: #{$PROGRAM_NAME} [options]"

    opts.on("-v", "--verbose", "Show verbose output") do
      options[:verbose] = true
    end

    opts.on("-r", "--register PATH", "Path to register directory") do |path|
      options[:register] = path
    end
  end.parse!

  detector = CoverageGapDetector.new(options)
  detector.run
end
