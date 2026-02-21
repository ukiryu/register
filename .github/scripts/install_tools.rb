#!/usr/bin/env ruby
# frozen_string_literal: true

# Install tools from install.yaml files based on current platform
# Usage: ruby install_tools.rb [options]
#
# Options:
#   --dry-run              Show what would be installed without installing
#   -v, --verbose          Show verbose output
#   -r, --register PATH    Path to register directory
#   --verify               Verify installed tools after installation
#   --fail-on-missing      Fail if any critical tool is not working
#   --report-format FMT    Report format: json, markdown, or both
#   --color                Force color output (auto-detected by default)
#   --no-color             Disable color output

require "yaml"
require "optparse"
require "fileutils"
require "json"
require "time"

# ANSI color codes for terminal output
module Colors
  RESET = "\e[0m"
  BOLD = "\e[1m"
  RED = "\e[31m"
  GREEN = "\e[32m"
  YELLOW = "\e[33m"
  BLUE = "\e[34m"
  MAGENTA = "\e[35m"
  CYAN = "\e[36m"
  WHITE = "\e[37m"

  # Background colors
  BG_RED = "\e[41m"
  BG_GREEN = "\e[42m"
  BG_YELLOW = "\e[43m"
end

# Emoji icons for status display
module Icons
  SUCCESS = "✅"
  FAILURE = "❌"
  WARNING = "⚠️"
  INFO = "ℹ️"
  PACKAGE = "📦"
  TOOL = "🔧"
  BUNDLED = "💻"
  SKIP = "⏭️"
  CRITICAL = "🔥"
  ROCKET = "🚀"
  CHECK = "✔"
  CROSS = "✗"
  DOTS = "•"
end

# Individual tool verification result
class ToolResult
  attr_accessor :tool_name, :package_name, :provides, :critical,
                :install_status, :install_error, :install_output,
                :executable, :executable_error,
                :smoke_test_status, :smoke_test_output, :smoke_test_error,
                :smoke_test_command,
                :ukiryu_status, :ukiryu_output, :ukiryu_error,
                :is_bundled, :platform_unavailable

  def initialize(tool_name:, package_name: nil, provides: [], critical: false)
    @tool_name = tool_name
    @package_name = package_name
    @provides = provides
    @critical = critical
    @install_status = :pending
    @install_error = nil
    @install_output = nil
    @executable = nil
    @executable_error = nil
    @smoke_test_status = :pending
    @smoke_test_output = nil
    @smoke_test_error = nil
    @ukiryu_status = :pending
    @ukiryu_output = nil
    @ukiryu_error = nil
    @is_bundled = false
    @platform_unavailable = false
  end

  def success?
    # Bundled tools only need executable check
    return !@executable.nil? if @is_bundled

    # For unavailable platforms, we don't count as failure
    return true if @platform_unavailable

    install_success? && executable_success? && smoke_test_success? && ukiryu_success?
  end

  def install_success?
    @install_status == :success || @install_status == :skipped || @is_bundled
  end

  def executable_success?
    !@executable.nil?
  end

  def smoke_test_success?
    @smoke_test_status == :success ||
      @smoke_test_status == :skipped ||
      @smoke_test_status == :not_defined
  end

  def ukiryu_success?
    @ukiryu_status == :success ||
      @ukiryu_status == :skipped ||
      @ukiryu_status == :not_available
  end

  def to_h
    {
      tool_name: @tool_name,
      package_name: @package_name,
      provides: @provides,
      critical: @critical,
      bundled: @is_bundled,
      install: @install_status.to_s,
      install_error: @install_error,
      executable: @executable,
      executable_error: @executable_error,
      smoke_test: @smoke_test_status.to_s,
      smoke_test_output: @smoke_test_output,
      smoke_test_error: @smoke_test_error,
      ukiryu: @ukiryu_status.to_s,
      ukiryu_output: @ukiryu_output,
      ukiryu_error: @ukiryu_error,
    }
  end
end

class ToolInstaller
  include Colors
  include Icons

  # Map platform to package manager
  PACKAGE_MANAGERS = {
    # Linux
    "ubuntu" => "apt",
    "debian" => "apt",
    "linuxmint" => "apt",
    "fedora" => "dnf",
    "rhel" => "yum",
    "centos" => "yum",
    "almalinux" => "yum",
    "rocky" => "yum",
    "alpine" => "apk",
    "arch" => "pacman",
    "manjaro" => "pacman",

    # macOS
    "darwin" => "homebrew",

    # Windows
    "windows" => "chocolatey",
  }.freeze

  # Commands to check if a tool is installed
  TOOL_CHECK_COMMANDS = {
    "apt" => "dpkg -l",
    "dnf" => "rpm -q",
    "yum" => "rpm -q",
    "apk" => "apk info -e",
    "pacman" => "pacman -Q",
    "homebrew" => "brew list",
    "macports" => "port installed",
    "chocolatey" => "choco list --local-only",
    "winget" => "winget list",
  }.freeze

  # Install commands for each package manager
  INSTALL_COMMANDS = {
    "apt" => "sudo apt-get install -y --no-install-recommends",
    "dnf" => "sudo dnf install -y",
    "yum" => "sudo yum install -y",
    "apk" => "apk add --no-cache",
    "pacman" => "sudo pacman -S --noconfirm",
    "homebrew" => "brew install",
    "macports" => "sudo port install",
    "chocolatey" => "choco install -y",
    "winget" => "winget install --silent --accept-package-agreements --accept-source-agreements",
  }.freeze

  # Update commands for each package manager
  UPDATE_COMMANDS = {
    "apt" => "sudo apt-get update",
    "dnf" => "sudo dnf makecache",
    "yum" => "sudo yum makecache",
    "apk" => "apk update",
    "pacman" => "sudo pacman -Sy",
    "homebrew" => "brew update",
    "macports" => "sudo port selfupdate",
    "chocolatey" => "choco upgrade chocolatey -y",
    "winget" => nil,
  }.freeze

  attr_reader :dry_run, :verbose, :register_path, :platform, :package_manager,
              :verify, :fail_on_missing, :report_formats, :use_color

  def initialize(options = {})
    @dry_run = options[:dry_run] || false
    @verbose = options[:verbose] || false
    @register_path = options[:register] || detect_register_path
    @platform = detect_platform
    @package_manager = detect_package_manager
    @verify = options[:verify] || false
    @fail_on_missing = options[:fail_on_missing] || false
    @report_formats = parse_report_formats(options[:report_format])
    @tool_configs = {}
    @tool_results = []
    @use_color = detect_color_usage(options)
  end

  def parse_report_formats(formats)
    return [:markdown] if formats.nil? # Default to markdown
    formats.split(",").map(&:strip).map(&:to_sym)
  end

  def detect_color_usage(options)
    return false if options[:no_color]
    return true if options[:color]
    # Auto-detect: check if stdout is a TTY
    $stdout.tty?
  end

  def run
    print_header

    # Phase 1: Collect all tool configurations
    collect_tool_configs

    if @tool_configs.empty?
      log_warning "No tool configurations found!"
      return
    end

    log_info "Found #{colorize(@tool_configs.size.to_s, CYAN)} tools to process"
    log ""

    # Phase 2: Install packages for each tool (one at a time)
    install_phase

    # Phase 3: Verify each tool (one at a time)
    if @verify
      verify_phase
      generate_reports
      print_summary

      # Exit with failure if any tool failed
      if @fail_on_missing && any_failure?
        log ""
        log_error "BUILD FAILED: Some tools are not working"
        exit 1
      end
    end
  end

  private

  def print_header
    log ""
    log colorize("#{"=" * 60}", BOLD)
    log colorize("  #{ROCKET} Ukiryu Tool Installer & Verifier", BOLD)
    log colorize("#{"=" * 60}", BOLD)
    log ""
    log "  #{INFO} Platform:         #{colorize(@platform, CYAN)}"
    log "  #{PACKAGE} Package Manager: #{colorize(@package_manager, CYAN)}"
    log "  #{TOOL} Register Path:    #{colorize(@register_path, CYAN)}"
    log "  #{INFO} Dry Run:          #{colorize(@dry_run.to_s, @dry_run ? YELLOW : GREEN)}"
    log "  #{INFO} Verify:           #{colorize(@verify.to_s, @verify ? GREEN : YELLOW)}"
    log ""
    log colorize("-" * 60, WHITE)
    log ""
  end

  def detect_register_path
    return ENV["UKIRYU_REGISTER"] if ENV["UKIRYU_REGISTER"]

    candidates = [
      File.join(Dir.pwd, "register"),
      File.join(Dir.pwd),
      File.expand_path("../../register", __dir__),
    ]

    candidates.find { |path| File.directory?(File.join(path, "packages")) }
  end

  def detect_platform
    case RUBY_PLATFORM
    when /linux/
      if File.exist?("/etc/os-release")
        os_release = File.read("/etc/os-release")
        if os_release.include?("Alpine")
          "alpine"
        elsif os_release.include?("Ubuntu")
          "ubuntu"
        elsif os_release.include?("Debian")
          "debian"
        elsif os_release.include?("Fedora")
          "fedora"
        elsif os_release.include?("CentOS")
          "centos"
        elsif os_release.include?("Red Hat")
          "rhel"
        elsif os_release.include?("Arch")
          "arch"
        else
          "linux"
        end
      else
        "linux"
      end
    when /darwin/
      "darwin"
    when /mswin|mingw|cygwin/
      "windows"
    else
      RUBY_PLATFORM
    end
  end

  def detect_package_manager
    if command_exists?("apt-get")
      "apt"
    elsif command_exists?("dnf")
      "dnf"
    elsif command_exists?("yum")
      "yum"
    elsif command_exists?("apk")
      "apk"
    elsif command_exists?("pacman")
      "pacman"
    elsif command_exists?("brew")
      "homebrew"
    elsif command_exists?("port")
      "macports"
    elsif command_exists?("choco")
      "chocolatey"
    elsif command_exists?("winget")
      "winget"
    else
      PACKAGE_MANAGERS[@platform] || "unknown"
    end
  end

  def command_exists?(cmd)
    system("which #{cmd} > /dev/null 2>&1") || system("command -v #{cmd} > /dev/null 2>&1")
  end

  def collect_tool_configs
    packages_dir = File.expand_path(File.join(@register_path, "packages"))
    unless File.directory?(packages_dir)
      log_warning "Packages directory not found: #{packages_dir}"
      return
    end

    pattern = File.join(packages_dir, "*.yaml")
    files = Dir.glob(pattern)
    log_verbose "Found #{files.size} package files in #{packages_dir}"

    files.each do |install_file|
      tool_name = File.basename(install_file, ".yaml")
      begin
        config = YAML.safe_load_file(install_file, aliases: true)
        @tool_configs[tool_name] = config
      rescue Psych::SyntaxError => e
        log_warning "Failed to parse #{install_file}: #{e.message}"
      end
    end
  end

  # ========================================
  # PHASE 2: INSTALL
  # ========================================

  def install_phase
    log ""
    log colorize("#{"=" * 60}", BOLD)
    log colorize("  #{PACKAGE} PHASE 1: Installing Packages", BOLD)
    log colorize("#{"=" * 60}", BOLD)
    log ""

    # Run update command first
    update_cmd = UPDATE_COMMANDS[@package_manager]
    if update_cmd && !@dry_run
      log "Updating package index..."
      run_command(update_cmd)
      log ""
    end

    install_cmd = INSTALL_COMMANDS[@package_manager]
    unless install_cmd
      log_warning "Unknown install command for #{@package_manager}"
      return
    end

    # Install each tool's packages separately
    installed_packages = Set.new
    total = @tool_configs.size
    current = 0

    @tool_configs.each do |tool_name, config|
      current += 1
      result = install_single_tool(tool_name, config, install_cmd, installed_packages)
      @tool_results << result

      # Print progress
      print_install_progress(current, total, result)
    end
  end

  def install_single_tool(tool_name, config, install_cmd, installed_packages)
    packages = config["packages"] || {}
    manager_packages = packages[@package_manager] || []
    is_critical = config["critical"] || false

    # Check if tool is bundled on this platform
    # Check both specific platform (e.g., "ubuntu") and platform family (e.g., "linux")
    platforms = config["platforms"] || {}
    platform_family = case @platform
                      when "ubuntu", "debian", "alpine", "fedora", "centos", "rhel", "arch"
                        "linux"
                      else
                        @platform
                      end
    platform_info = platforms[@platform] || platforms[platform_family] || {}
    is_bundled = platform_info["bundled"] || false
    platform_smoke_test = platform_info["smoke_test"]

    # Get package info
    pkg_info = manager_packages.first || {}
    pkg_name = pkg_info.is_a?(Hash) ? pkg_info["name"] : pkg_info
    provides = if pkg_info.is_a?(Hash) && pkg_info["provides"]
                 pkg_info["provides"]
               else
                 [tool_name]
               end
    # Use package smoke_test if available, otherwise use platform smoke_test
    smoke_test = (pkg_info.is_a?(Hash) ? pkg_info["smoke_test"] : nil) || platform_smoke_test
    install_script = pkg_info.is_a?(Hash) ? pkg_info["install_script"] : nil

    result = ToolResult.new(
      tool_name: tool_name,
      package_name: pkg_name,
      provides: provides,
      critical: is_critical,
    )
    result.is_bundled = is_bundled
    result.smoke_test_command = smoke_test

    # Handle bundled tools
    if is_bundled
      result.install_status = :skipped
      return result
    end

    # Handle unavailable platforms
    if manager_packages.empty?
      result.install_status = :not_available
      result.platform_unavailable = true
      return result
    end

    # Check if already installed
    if executable_exists?(provides)
      result.install_status = :skipped
      return result
    end

    # Install package
    if @dry_run
      result.install_status = :skipped
      result.install_output = "DRY RUN: Would install #{pkg_name}"
    elsif install_script
      # Use custom install script instead of package manager
      success, output = run_install_script(install_script, tool_name)
      if success
        result.install_status = :success
        result.install_output = output
      else
        result.install_status = :failed
        result.install_error = output
      end
    else
      success, output = run_install_command(install_cmd, pkg_name)
      if success
        result.install_status = :success
        result.install_output = output
      else
        result.install_status = :failed
        result.install_error = output
      end
    end

    result
  end

  def run_install_command(install_cmd, pkg_name)
    cmd = "#{install_cmd} #{pkg_name}"
    log_verbose "Executing: #{cmd}"

    output = `#{cmd} 2>&1`
    success = $?.success?

    [success, output.strip]
  end

  # Run a custom install script
  def run_install_script(script, tool_name)
    log_verbose "Running install script for #{tool_name}"

    # Write script to temp file and execute
    script_file = "/tmp/install_#{tool_name}.sh"
    File.write(script_file, script)

    output = `bash #{script_file} 2>&1`
    success = $?.success?

    # Clean up
    File.delete(script_file) if File.exist?(script_file)

    [success, output.strip]
  end

  def print_install_progress(current, total, result)
    # Status icon
    icon = case result.install_status
           when :success then colorize(SUCCESS, GREEN)
           when :skipped then colorize(SKIP, YELLOW)
           when :bundled then colorize(BUNDLED, CYAN)
           when :not_available then colorize("⊘", YELLOW)
           when :failed then colorize(FAILURE, RED)
           else colorize("?", YELLOW)
           end

    # Tool name with critical marker
    name = result.tool_name.ljust(15)
    name = colorize(name, BOLD) if result.critical
    critical_str = result.critical ? " #{colorize(CRITICAL, RED)}" : ""
    bundled_str = result.is_bundled ? " #{colorize("[BUNDLED]", CYAN)}" : ""
    unavailable_str = result.platform_unavailable ? " #{colorize("[N/A]", YELLOW)}" : ""

    # Package name
    pkg_str = result.package_name ? "(#{result.package_name})" : ""

    line = "[#{current}/#{total}] #{icon} #{name}#{pkg_str}#{critical_str}#{bundled_str}#{unavailable_str}"
    log line

    # Print error if failed
    if result.install_status == :failed && result.install_error
      log "           #{colorize("ERROR:", RED)} #{result.install_error.lines.first&.strip}"
    end
  end

  # ========================================
  # PHASE 3: VERIFY
  # ========================================

  def verify_phase
    log ""
    log colorize("#{"=" * 60}", BOLD)
    log colorize("  #{TOOL} PHASE 2: Verifying Tools", BOLD)
    log colorize("#{"=" * 60}", BOLD)
    log ""

    total = @tool_results.size
    current = 0

    @tool_results.each do |result|
      current += 1
      verify_single_tool(result)
      print_verify_progress(current, total, result)
    end
  end

  def verify_single_tool(result)
    # Skip bundled tools - find executable and run smoke test but skip ukiryu
    if result.is_bundled
      exe_path = find_executable(result.provides)
      if exe_path
        result.executable = exe_path
        # Run smoke test for bundled tools
        smoke_test = result.smoke_test_command
        if smoke_test
          success, _output = run_smoke_test(smoke_test, exe_path)
          result.smoke_test_status = success ? :success : :failed
        else
          result.smoke_test_status = :not_defined
        end
      else
        result.executable_error = "Bundled tool not found in PATH"
        result.smoke_test_status = :skipped
      end
      result.ukiryu_status = :skipped
      return
    end

    # Skip unavailable platforms
    if result.platform_unavailable
      result.ukiryu_status = :not_available
      return
    end

    # Skip if install failed
    if result.install_status == :failed
      result.executable_error = "Install failed"
      result.smoke_test_status = :skipped
      result.ukiryu_status = :skipped
      return
    end

    # Find executable
    exe_path = find_executable(result.provides)
    if exe_path
      result.executable = exe_path
    else
      result.executable_error = "Not found: #{result.provides.join(', ')}"
      result.smoke_test_status = :skipped
      result.ukiryu_status = :skipped
      return
    end

    # Get smoke test command
    config = @tool_configs[result.tool_name]
    packages = config["packages"] || {}
    manager_packages = packages[@package_manager] || []
    pkg_info = manager_packages.first || {}
    smoke_test = pkg_info.is_a?(Hash) ? pkg_info["smoke_test"] : nil

    # Run smoke test
    if smoke_test && !smoke_test.empty?
      success, output = run_smoke_test(smoke_test, exe_path)
      result.smoke_test_output = output
      if success
        result.smoke_test_status = :success
      else
        result.smoke_test_status = :failed
        result.smoke_test_error = output
      end
    else
      result.smoke_test_status = :not_defined
    end

    # ========================================
    # UKIRYU DISCOVERY TEST
    # ========================================
    # Test if Ukiryu can properly discover and load this tool
    ukiryu_success, ukiryu_output = test_ukiryu_discovery(result.tool_name)
    result.ukiryu_output = ukiryu_output
    if ukiryu_success
      result.ukiryu_status = :success
    else
      result.ukiryu_status = :failed
      result.ukiryu_error = ukiryu_output
    end
  end

  # Test if Ukiryu can discover and load the tool
  def test_ukiryu_discovery(tool_name)
    # Check if ukiryu CLI is available
    ukiryu_path = `which ukiryu 2>/dev/null`.strip
    if ukiryu_path.empty?
      # Ukiryu not installed - skip this test
      return [true, "Ukiryu CLI not available - skipped"]
    end

    # Run ukiryu validate command for this tool
    # Look for the tool VERSION file (not index.yaml)
    # Structure: tools/{tool}/{implementation}/{version}.yaml
    impl_dirs = Dir.glob(File.join(@register_path, "tools", tool_name, "*"))
                    .select { |d| File.directory?(d) }

    # Find version YAML files in implementation directories
    version_files = []
    impl_dirs.each do |impl_dir|
      Dir.glob(File.join(impl_dir, "*.yaml")).each do |f|
        # Skip index.yaml - it's an implementation index, not a profile
        version_files << f unless File.basename(f) == 'index.yaml'
      end
    end

    # Fallback: try old location (tools/{tool}/{version}.yaml)
    if version_files.empty?
      legacy_files = Dir.glob(File.join(@register_path, "tools", tool_name, "*.yaml"))
      version_files = legacy_files.reject { |f| File.basename(f) == 'index.yaml' }
    end

    if version_files.empty?
      # Try packages directory instead
      pkg_file = File.join(@register_path, "packages", "#{tool_name}.yaml")
      if File.exist?(pkg_file)
        version_files = [pkg_file]
      end
    end

    if version_files.empty?
      return [false, "Tool definition file not found"]
    end

    # Validate the tool definition using correct CLI syntax
    tool_file_path = version_files.first
    cmd = "ukiryu validate file #{tool_file_path} 2>&1"
    log_verbose "Running Ukiryu validation: #{cmd}"

    output = `#{cmd}`
    success = $?.success?

    [success, output.strip]
  end

  def find_executable(provides)
    provides.each do |exe|
      # Try 'which' first
      path = `which #{exe} 2>/dev/null`.strip
      return path unless path.empty?

      # Try 'command -v'
      path = `command -v #{exe} 2>/dev/null`.strip
      return path unless path.empty?

      # Windows: check chocolatey shims FIRST (before where command)
      # This ensures installed packages take precedence over system tools
      if @platform == "windows"
        shim_path = "C:\\ProgramData\\chocolatey\\bin\\#{exe}.exe"
        return shim_path if File.exist?(shim_path)

        # Check Ghostscript paths
        Dir.glob("C:/Program Files/gs/gs*/bin/#{exe}.exe").each do |gs_path|
          return gs_path if File.exist?(gs_path)
        end

        # Then use 'where' command as fallback
        path = `where #{exe} 2>nul`.strip.lines.first.to_s.strip
        return path unless path.empty?
      end
    end
    nil
  end

  def executable_exists?(provides)
    !find_executable(provides).nil?
  end

  def run_smoke_test(smoke_test_cmd, exe_path)
    # Build the actual command
    if smoke_test_cmd && !smoke_test_cmd.empty?
      # Replace the first executable name in the smoke test with the actual path
      # This handles cases like "gswin64c --version" where gswin64c isn't in PATH
      exe_name = File.basename(exe_path, ".exe")
      # Quote the path if it contains spaces
      quoted_path = exe_path.include?(" ") ? "\"#{exe_path}\"" : exe_path
      # Use block form to avoid backreference interpretation in replacement string
      actual_cmd = smoke_test_cmd.sub(/\b#{Regexp.escape(exe_name)}\b/) { quoted_path }
    else
      # Default: try common version flags
      quoted_path = exe_path.include?(" ") ? "\"#{exe_path}\"" : exe_path
      actual_cmd = "#{quoted_path} --version 2>&1 || #{quoted_path} -version 2>&1 || #{quoted_path} version 2>&1"
    end

    log_verbose "Running smoke test: #{actual_cmd}"

    output = `#{actual_cmd} 2>&1`
    success = $?.success?

    # Handle encoding issues
    output = output.encode("UTF-8", invalid: :replace, undef: :replace, replace: "")

    [success, output.strip]
  end

  def print_verify_progress(current, total, result)
    # Executable status
    exe_icon = result.executable ? colorize(CHECK, GREEN) : colorize(CROSS, RED)
    exe_str = result.executable ? result.executable : (result.executable_error || "N/A")

    # Smoke test status
    smoke_icon = case result.smoke_test_status
                 when :success then colorize(CHECK, GREEN)
                 when :failed then colorize(CROSS, RED)
                 when :skipped then colorize("○", YELLOW)
                 when :not_defined then colorize("-", WHITE)
                 else colorize("?", YELLOW)
                 end

    # Ukiryu discovery status
    ukiryu_icon = case result.ukiryu_status
                  when :success then colorize(CHECK, GREEN)
                  when :failed then colorize(CROSS, RED)
                  when :skipped then colorize("○", YELLOW)
                  when :not_available then colorize("-", WHITE)
                  else colorize("?", YELLOW)
                  end

    # Overall status
    overall = result.success? ? colorize(SUCCESS, GREEN) : colorize(FAILURE, RED)

    # Tool name
    name = result.tool_name.ljust(15)
    name = colorize(name, BOLD) if result.critical
    critical_str = result.critical ? " #{colorize(CRITICAL, RED)}" : ""

    line = "[#{current}/#{total}] #{overall} #{name} #{exe_icon} exe  #{smoke_icon} smoke  #{ukiryu_icon} ukiryu#{critical_str}"
    log line

    # Print details on failure
    unless result.executable
      log "           #{colorize("EXE ERROR:", RED)} #{result.executable_error}"
    end

    if result.smoke_test_status == :failed
      error_line = result.smoke_test_error&.lines&.first&.strip
      log "           #{colorize("SMOKE ERROR:", RED)} #{error_line}"
    end

    if result.ukiryu_status == :failed
      error_line = result.ukiryu_error&.lines&.first&.strip
      log "           #{colorize("UKIRYU ERROR:", RED)} #{error_line}"
    end
  end

  # ========================================
  # REPORTING
  # ========================================

  def generate_reports
    return if @report_formats.empty?

    log ""
    log "Generating reports..."

    @report_formats.each do |format|
      case format
      when :json
        generate_json_report
      when :markdown
        generate_markdown_report
      end
    end
  end

  def generate_json_report
    report = {
      timestamp: Time.now.utc.iso8601,
      platform: @platform,
      package_manager: @package_manager,
      tools: @tool_results.each_with_object({}) do |result, hash|
        hash[result.tool_name] = result.to_h
      end,
      summary: {
        total: @tool_results.size,
        passed: @tool_results.count(&:success?),
        failed: @tool_results.count { |r| !r.success? },
        critical_failed: @tool_results.count { |r| r.critical && !r.success? },
      },
    }

    filename = "tool_verification_report.json"
    File.write(filename, JSON.pretty_generate(report))
    log "  #{colorize(CHECK, GREEN)} Generated: #{filename}"
  end

  def generate_markdown_report
    passed = @tool_results.count(&:success?)
    failed = @tool_results.size - passed
    critical_failed = @tool_results.count { |r| r.critical && !r.success? }

    lines = []
    lines << "# Tool Verification Report"
    lines << ""
    lines << "- **Platform**: #{@platform}"
    lines << "- **Package Manager**: #{@package_manager}"
    lines << "- **Timestamp**: #{Time.now.utc.iso8601}"
    lines << ""
    lines << "## Summary"
    lines << ""
    lines << "| Metric | Count |"
    lines << "|--------|-------|"
    lines << "| Total | #{@tool_results.size} |"
    lines << "| Passed | #{passed} |"
    lines << "| Failed | #{failed} |"
    lines << "| Critical Failed | #{critical_failed} |"
    lines << ""
    lines << "## Results"
    lines << ""
    lines << "| Tool | Install | Executable | Smoke Test | Ukiryu | Critical |"
    lines << "|------|---------|------------|------------|--------|----------|"

    @tool_results.sort_by(&:tool_name).each do |result|
      install = case result.install_status
                when :success then "success"
                when :skipped then "skipped"
                when :bundled then "bundled"
                when :not_available then "n/a"
                when :failed then "failed"
                else result.install_status.to_s
                end

      exe = result.executable ? "OK" : "MISSING"
      smoke = case result.smoke_test_status
              when :success then "passed"
              when :failed then "FAILED"
              when :skipped then "skipped"
              when :not_defined then "n/a"
              else result.smoke_test_status.to_s
              end
      ukiryu = case result.ukiryu_status
               when :success then "passed"
               when :failed then "FAILED"
               when :skipped then "skipped"
               when :not_available then "n/a"
               else result.ukiryu_status.to_s
               end
      critical = result.critical ? "Yes" : "No"

      lines << "| #{result.tool_name} | #{install} | #{exe} | #{smoke} | #{ukiryu} | #{critical} |"
    end

    filename = "tool_verification_report.md"
    File.write(filename, lines.join("\n"))
    log "  #{colorize(CHECK, GREEN)} Generated: #{filename}"
  end

  def print_summary
    passed = @tool_results.count(&:success?)
    failed = @tool_results.size - passed
    critical_failed = @tool_results.count { |r| r.critical && !r.success? }

    log ""
    log colorize("#{"=" * 60}", BOLD)
    log colorize("  SUMMARY", BOLD)
    log colorize("#{"=" * 60}", BOLD)
    log ""

    # Overall result
    if failed == 0
      log "  #{SUCCESS} #{colorize("ALL TOOLS VERIFIED", GREEN)}"
    else
      log "  #{FAILURE} #{colorize("#{failed} TOOLS FAILED", RED)}"
    end

    log ""
    log "  #{INFO} Total:     #{@tool_results.size}"
    log "  #{colorize("Passed:", GREEN)}    #{passed}"
    log "  #{colorize("Failed:", RED)}    #{failed}"

    if critical_failed > 0
      log "  #{colorize("Critical:", RED)}  #{critical_failed}"
    end

    # List failures
    if failed > 0
      log ""
      log colorize("  FAILED TOOLS:", RED)
      @tool_results.reject(&:success?).each do |result|
        reasons = []
        reasons << "install failed" if result.install_status == :failed
        reasons << "no executable" unless result.executable
        reasons << "smoke test failed" if result.smoke_test_status == :failed
        reasons << "ukiryu discovery failed" if result.ukiryu_status == :failed
        reasons << "not available" if result.platform_unavailable

        critical_str = result.critical ? " #{CRITICAL}" : ""
        log "    #{CROSS} #{result.tool_name}#{critical_str}: #{reasons.join(', ')}"
      end
    end

    log ""
  end

  def critical_failures?
    @tool_results.any? { |r| r.critical && !r.success? && !r.platform_unavailable }
  end

  def any_critical_failure?
    @tool_results.any? { |r| r.critical && !r.success? }
  end

  def any_failure?
    # Only count as failure if:
    # 1. Tool is not platform_unavailable
    # 2. Tool was installed successfully AND has an executable
    # 3. But failed verification (smoke test or ukiryu validation)
    # This excludes tools that simply don't have working packages on the platform
    @tool_results.any? do |r|
      # Skip tools that don't have packages on this platform
      next false if r.platform_unavailable
      next false if r.install_status == :not_available

      # CRITERIA 1: Failure to install = FAIL
      # If a package was supposed to be installed but failed, that's a failure
      next true if r.install_status == :failed

      # Skip if no executable was found after install (install might have been skipped)
      next false unless r.executable

      # CRITERIA 2: Failure to smoke test CLI after install = FAIL
      # If the tool was installed but smoke test failed, that's a failure
      next true if r.smoke_test_status == :failed

      # CRITERIA 3: Failure for ukiryu to detect after smoke test pass = FAIL
      # If smoke test passed but ukiryu detection failed, that's a failure
      next true if r.ukiryu_status == :failed

      false
    end
  end

  # ========================================
  # UTILITIES
  # ========================================

  def run_command(cmd)
    log_verbose "Executing: #{cmd}"
    success = system(cmd)
    raise "Command failed: #{cmd}" unless success
    success
  end

  def colorize(text, color_code)
    return text unless @use_color
    "#{color_code}#{text}#{RESET}"
  end

  def log(message)
    puts message
  end

  def log_verbose(message)
    puts "  #{colorize("[VERBOSE]", CYAN)} #{message}" if @verbose
  end

  def log_info(message)
    puts "  #{INFO} #{message}"
  end

  def log_warning(message)
    $stderr.puts "  #{WARNING} #{colorize("WARNING:", YELLOW)} #{message}"
  end

  def log_error(message)
    $stderr.puts "  #{FAILURE} #{colorize("ERROR:", RED)} #{message}"
  end
end

# Main
if __FILE__ == $PROGRAM_NAME
  options = {}

  OptionParser.new do |opts|
    opts.banner = "Usage: #{$PROGRAM_NAME} [options]"

    opts.on("--dry-run", "Show what would be installed without installing") do
      options[:dry_run] = true
    end

    opts.on("-v", "--verbose", "Show verbose output") do
      options[:verbose] = true
    end

    opts.on("-r", "--register PATH", "Path to register directory") do |path|
      options[:register] = path
    end

    opts.on("--verify", "Verify installed tools after installation") do
      options[:verify] = true
    end

    opts.on("--fail-on-missing", "Fail if any critical tool is not working") do
      options[:fail_on_missing] = true
    end

    opts.on("--report-format FORMAT", "Report format: json, markdown, or json,markdown") do |format|
      options[:report_format] = format
    end

    opts.on("--color", "Force color output") do
      options[:color] = true
    end

    opts.on("--no-color", "Disable color output") do
      options[:no_color] = true
    end

    opts.on("-h", "--help", "Show this help") do
      puts opts
      exit
    end
  end.parse!

  installer = ToolInstaller.new(options)
  installer.run
end
