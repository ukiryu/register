#!/usr/bin/env ruby
# frozen_string_literal: true

require 'yaml'
require 'fileutils'

##
# Migrates register YAML files from individual shell enumeration to platform groups.
#
# Transforms:
#   [bash, zsh, fish, sh, dash, tcsh] → [unix]
#   [powershell] → [powershell]
#   [cmd] → [windows]
#
# Preserves mixed cases like [bash, powershell] → [unix, powershell]

module Ukiryu
  module Migrate
    class ShellMigrator
      # Unix-like shells that share quoting/escaping rules
      UNIX_SHELLS = %w[bash zsh fish sh dash tcsh ash csh ksh].freeze

      # Platform group mappings
      PLATFORM_GROUPS = {
        'unix' => UNIX_SHELLS,
        'windows' => ['cmd'],
        'powershell' => ['powershell', 'pwsh']
      }.freeze

      attr_reader :dry_run, :verbose

      def initialize(dry_run: false, verbose: false)
        @dry_run = dry_run
        @verbose = verbose
      end

      # Migrate a single YAML file
      #
      # @param file_path [String] path to YAML file
      # @return [Hash] migration result
      def migrate_file(file_path)
        content = File.read(file_path)
        yaml = YAML.safe_load(content, permitted_classes: [Symbol])

        return { status: :skipped, reason: 'no shells key' } unless yaml['profiles']

        changed = false
        yaml['profiles'].each_with_index do |profile, _idx|
          next unless profile['shells']

          original_shells = profile['shells']
          new_shells = convert_shells(original_shells)

          if new_shells != original_shells
            profile['shells'] = new_shells
            changed = true

            if verbose
              puts "  #{file_path}:"
              puts "    #{original_shells.inspect} → #{new_shells.inspect}"
            end
          end
        end

        return { status: :skipped, reason: 'no changes needed' } unless changed

        unless dry_run
          File.write(file_path, yaml.to_yaml.gsub(/^---\n/, ''))
          puts "✓ Updated: #{file_path}" if verbose
        end

        { status: :updated, file: file_path }
      rescue Psych::SyntaxError => e
        { status: :error, file: file_path, error: "Invalid YAML: #{e.message}" }
      end

      # Migrate all YAML files in a directory
      #
      # @param dir_path [String] path to register tools directory
      # @return [Hash] migration summary
      def migrate_directory(dir_path)
        yaml_files = Dir.glob(File.join(dir_path, '*', '*.yaml')).sort

        # Skip index.yaml files
        yaml_files = yaml_files.reject { |f| File.basename(f) == 'index.yaml' }

        puts "Migrating #{yaml_files.length} YAML files..."
        puts "DRY RUN - no files will be modified" if dry_run
        puts

        summary = {
          total: yaml_files.length,
          updated: 0,
          skipped: 0,
          errors: 0,
          files: []
        }

        yaml_files.each do |file_path|
          result = migrate_file(file_path)

          case result[:status]
          when :updated
            summary[:updated] += 1
            summary[:files] << result
          when :skipped
            summary[:skipped] += 1
          when :error
            summary[:errors] += 1
            summary[:files] << result
            puts "✗ Error: #{file_path} - #{result[:error]}"
          end
        end

        summary
      end

      private

      # Convert shell list to platform groups
      #
      # @param shells [Array<String>] list of shells
      # @return [Array<String>] list of platform groups
      def convert_shells(shells)
        return shells if shells.nil? || shells.empty?

        # Determine which platform groups are represented
        platform_groups = Set.new

        shells.each do |shell|
          platform_group = find_platform_group(shell)
          platform_groups.add(platform_group) if platform_group
        end

        # Sort for consistent output: unix, windows, powershell
        platform_groups.to_a.sort
      end

      # Find the platform group for a given shell name
      #
      # @param shell [String] shell name
      # @return [String, nil] platform group or nil if unknown
      def find_platform_group(shell)
        PLATFORM_GROUPS.each do |group, group_shells|
          return group if group_shells.include?(shell)
        end

        # Unknown shell - warn but don't crash
        warn "Warning: Unknown shell '#{shell}' - treating as unix" if verbose
        'unix' # Default to unix for unknown shells (likely future Unix shells)
      end
    end
  end
end

# CLI interface
if __FILE__ == $PROGRAM_NAME
  require 'optparse'

  options = {
    dry_run: false,
    verbose: false
  }

  OptionParser.new do |opts|
    opts.banner = "Usage: #{File.basename(__FILE__)} [options] [directory]"

    opts.on('-n', '--dry-run', 'Show what would change without modifying files') do
      options[:dry_run] = true
    end

    opts.on('-v', '--verbose', 'Show detailed output') do
      options[:verbose] = true
    end

    opts.on('-h', '--help', 'Show this message') do
      puts opts
      puts <<~HELP

        Migrates register YAML files from individual shell enumeration to platform groups.

        Transforms:
          [bash, zsh, fish, sh, dash, tcsh] → [unix]
          [powershell] → [powershell]
          [cmd] → [windows]
          [bash, powershell] → [unix, powershell]

        Options:
          directory - Path to register tools directory (default: ./tools)
      HELP
      exit
    end
  end.parse!

  # Default to ./tools directory
  dir_path = ARGV[0] || File.join(Dir.pwd, 'tools')

  unless Dir.exist?(dir_path)
    puts "Error: Directory not found: #{dir_path}"
    exit 1
  end

  migrator = Ukiryu::Migrate::ShellMigrator.new(
    dry_run: options[:dry_run],
    verbose: options[:verbose]
  )

  summary = migrator.migrate_directory(dir_path)

  puts
  puts "Migration Summary:"
  puts "  Total files: #{summary[:total]}"
  puts "  Updated: #{summary[:updated]}"
  puts "  Skipped: #{summary[:skipped]}"
  puts "  Errors: #{summary[:errors]}"

  if summary[:errors] > 0
    exit 1
  elsif options[:dry_run] && summary[:updated] > 0
    puts "\nDRY RUN complete. Run without --dry-run to apply changes."
  end
end
