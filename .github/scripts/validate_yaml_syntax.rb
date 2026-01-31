# frozen_string_literal: true

require 'yaml'
require 'pathname'

module Ukiryu
  module Scripts
    class ValidateYamlSyntax
      def self.call
        tools_dir = 'tools'

        unless File.directory?(tools_dir)
          puts 'No tools directory found'
          exit 0
        end

        yaml_files = Dir.glob(File.join(tools_dir, '**', '*.yaml')).sort

        failed_files = []
        valid_count = 0

        yaml_files.each do |yaml_file|
          YAML.load_file(yaml_file)
          valid_count += 1
        rescue Psych::SyntaxError => e
          failed_files << { file: yaml_file, error: e.message }
        rescue StandardError => e
          failed_files << { file: yaml_file, error: e.message }
        end

        if failed_files.any?
          write_summary(yaml_files.size, valid_count, failed_files)
          exit 1
        else
          puts "✅ All #{valid_count} YAML files are valid"
          exit 0
        end
      end

      def self.write_summary(total_files, valid_count, failed_files)
        summary_file = ENV.fetch('GITHUB_STEP_SUMMARY', nil)

        if summary_file
          File.open(summary_file, 'w') do |f|
            f.puts "# YAML Validation Results\n\n"
            f.puts "## ❌ Validation Failed\n\n"
            f.puts "**Total files checked:** #{total_files}\n"
            f.puts "**Valid files:** #{valid_count}\n"
            f.puts "**Failed files:** #{failed_files.size}\n\n"
            f.puts "### Failed Files\n\n"

            failed_files.each do |failure|
              relative_path = Pathname.new(failure[:file]).relative_path(Dir.pwd)
              f.puts "- **#{relative_path}**\n"
              f.puts "  ```\n"
              f.puts "  #{failure[:error]}\n"
              f.puts "  ```\n\n"
            end
          end

          puts 'YAML validation summary written to GITHUB_STEP_SUMMARY'
        else
          puts '## ❌ Validation Failed'
          puts "**Total files checked:** #{total_files}"
          puts "**Valid files:** #{valid_count}"
          puts "**Failed files:** #{failed_files.size}"
          puts "\n### Failed Files"

          failed_files.each do |failure|
            relative_path = Pathname.new(failure[:file]).relative_path(Dir.pwd)
            puts "- #{relative_path}"
            puts "  Error: #{failure[:error]}"
          end
        end
      end
    end
  end
end

Ukiryu::Scripts::ValidateYamlSyntax.call if __FILE__ == $PROGRAM_NAME
