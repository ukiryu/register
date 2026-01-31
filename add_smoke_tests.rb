#!/usr/bin/env ruby
# frozen_string_literal: true

require 'yaml'
require 'pathname'

# Smoke test templates for common tool types
SMOKE_TEST_TEMPLATES = {
  version_test: {
    name: 'version',
    description: 'Verify tool version',
    command: ['--version'],
    expect: { exit_code: 0 }
  },
  help_test: {
    name: 'help',
    description: 'Verify help output',
    command: ['--help'],
    expect: { exit_code: 0 }
  },
  # For tools that use -v instead of --version
  version_flag_short: {
    name: 'version',
    description: 'Verify tool version',
    command: ['-v'],
    expect: { exit_code: 0 }
  },
  # For tools that use -h instead of --help
  help_flag_short: {
    name: 'help',
    description: 'Verify help output',
    command: ['-h'],
    expect: { exit_code: 0 }
  },
  # For tools that use "version" as a command
  version_command: {
    name: 'version',
    description: 'Verify tool version',
    command: ['version'],
    expect: { exit_code: 0 }
  }
}

# Tools that don't support standard version/help flags
SKIP_TOOLS = %w[
  grep sed awk cat head tail cut xargs tee
].freeze

# Tools that need special handling
SPECIAL_TOOL_HANDLERS = {
  # Add special handlers here if needed
}

# Generate smoke tests for a tool profile
def generate_smoke_tests(profile_data, file_path)
  tool_name = profile_data['name'] || profile_data[:name]
  return nil if SKIP_TOOLS.include?(tool_name)

  smoke_tests = []

  # Check if version_detection exists to determine version command
  version_detection = profile_data['version_detection'] || profile_data[:version_detection]

  if version_detection
    version_command = version_detection['command'] || version_detection[:command]
    if version_command.is_a?(Array)
      cmd = version_command
    elsif version_command.is_a?(String)
      # Determine if it's a flag or subcommand
      if version_command.start_with?('-')
        cmd = [version_command]
      else
        cmd = [version_command]
      end
    end

    # Create version test
    smoke_tests << {
      'name' => 'version',
      'description' => "Verify #{tool_name} version",
      'command' => cmd,
      'expect' => { 'exit_code' => 0 }
    }
  else
    # Fallback to --version
    smoke_tests << SMOKE_TEST_TEMPLATES[:version_test].dup
  end

  # Add help test if the tool has commands (most CLI tools support --help)
  smoke_tests << SMOKE_TEST_TEMPLATES[:help_test].dup

  smoke_tests
end

# Main processing
def process_file(file_path)
  begin
    content = File.read(file_path)
    profile_data = YAML.safe_load(content, permitted_classes: [Symbol, Date, Time])

    # Skip if already has smoke_tests
    if profile_data['smoke_tests'] || profile_data[:smoke_tests]
      puts "⊘ #{file_path} already has smoke_tests"
      return
    end

    smoke_tests = generate_smoke_tests(profile_data, file_path)

    if smoke_tests && !smoke_tests.empty?
      # Add smoke_tests to profile
      profile_data['smoke_tests'] = smoke_tests

      # Write back to file
      File.write(file_path, profile_data.to_yaml)

      puts "✓ Added smoke tests to #{file_path}"
    else
      puts "⊘ Skipped #{file_path} (no smoke tests generated)"
    end
  rescue StandardError => e
    puts "✗ Error processing #{file_path}: #{e.message}"
  end
end

# Find and process all tool profiles
tools_dir = Pathname.new('tools')
yaml_files = tools_dir.glob('**/*.yaml').sort

puts "Found #{yaml_files.length} tool profile files"
puts "Adding smoke tests..."
puts ""

yaml_files.each do |file|
  process_file(file.to_s)
end

puts ""
puts "Done! Review changes and commit."
