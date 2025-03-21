# typed: true # rubocop:todo Sorbet/StrictSigil
# frozen_string_literal: true

require "utils/formatter"

module Homebrew
  module Bundle
    module Commands
      # TODO: refactor into multiple modules
      module Cleanup
        module_function

        def reset!
          @dsl = nil
          @kept_casks = nil
          @kept_formulae = nil
          Homebrew::Bundle::CaskDumper.reset!
          Homebrew::Bundle::BrewDumper.reset!
          Homebrew::Bundle::TapDumper.reset!
          Homebrew::Bundle::VscodeExtensionDumper.reset!
          Homebrew::Bundle::BrewServices.reset!
        end

        def run(global: false, file: nil, force: false, zap: false, dsl: nil)
          @dsl ||= dsl

          casks = casks_to_uninstall(global:, file:)
          formulae = formulae_to_uninstall(global:, file:)
          taps = taps_to_untap(global:, file:)
          vscode_extensions = vscode_extensions_to_uninstall(global:, file:)
          if force
            if casks.any?
              args = zap ? ["--zap"] : []
              Kernel.system HOMEBREW_BREW_FILE, "uninstall", "--cask", *args, "--force", *casks
              puts "Uninstalled #{casks.size} cask#{(casks.size == 1) ? "" : "s"}"
            end

            if formulae.any?
              Kernel.system HOMEBREW_BREW_FILE, "uninstall", "--formula", "--force", *formulae
              puts "Uninstalled #{formulae.size} formula#{(formulae.size == 1) ? "" : "e"}"
            end

            Kernel.system HOMEBREW_BREW_FILE, "untap", *taps if taps.any?

            Bundle.exchange_uid_if_needed! do
              vscode_extensions.each do |extension|
                Kernel.system(Bundle.which_vscode, "--uninstall-extension", extension)
              end
            end

            cleanup = system_output_no_stderr(HOMEBREW_BREW_FILE, "cleanup")
            puts cleanup unless cleanup.empty?
          else
            would_uninstall = false

            if casks.any?
              puts "Would uninstall casks:"
              puts Formatter.columns casks
              would_uninstall = true
            end

            if formulae.any?
              puts "Would uninstall formulae:"
              puts Formatter.columns formulae
              would_uninstall = true
            end

            if taps.any?
              puts "Would untap:"
              puts Formatter.columns taps
              would_uninstall = true
            end

            if vscode_extensions.any?
              puts "Would uninstall VSCode extensions:"
              puts Formatter.columns vscode_extensions
              would_uninstall = true
            end

            cleanup = system_output_no_stderr(HOMEBREW_BREW_FILE, "cleanup", "--dry-run")
            unless cleanup.empty?
              puts "Would `brew cleanup`:"
              puts cleanup
            end

            puts "Run `brew bundle cleanup --force` to make these changes." if would_uninstall || !cleanup.empty?
            exit 1 if would_uninstall
          end
        end

        def casks_to_uninstall(global: false, file: nil)
          Homebrew::Bundle::CaskDumper.cask_names - kept_casks(global:, file:)
        end

        def formulae_to_uninstall(global: false, file: nil)
          kept_formulae = self.kept_formulae(global:, file:)

          current_formulae = Homebrew::Bundle::BrewDumper.formulae
          current_formulae.reject! do |f|
            Homebrew::Bundle::BrewInstaller.formula_in_array?(f[:full_name], kept_formulae)
          end
          current_formulae.map { |f| f[:full_name] }
        end

        def kept_formulae(global: false, file: nil)
          @kept_formulae ||= begin
            @dsl ||= Brewfile.read(global:, file:)

            kept_formulae = @dsl.entries.select { |e| e.type == :brew }.map(&:name)
            kept_formulae += Homebrew::Bundle::CaskDumper.formula_dependencies(kept_casks)
            kept_formulae.map! do |f|
              Homebrew::Bundle::BrewDumper.formula_aliases[f] ||
                Homebrew::Bundle::BrewDumper.formula_oldnames[f] ||
                f
            end

            kept_formulae + recursive_dependencies(Homebrew::Bundle::BrewDumper.formulae, kept_formulae)
          end
        end

        def kept_casks(global: false, file: nil)
          return @kept_casks if @kept_casks

          @dsl ||= Brewfile.read(global:, file:)
          @kept_casks = @dsl.entries.select { |e| e.type == :cask }.map(&:name)
        end

        def recursive_dependencies(current_formulae, formulae_names, top_level: true)
          @checked_formulae_names = [] if top_level
          dependencies = T.let([], T::Array[Formula])

          formulae_names.each do |name|
            next if @checked_formulae_names.include?(name)

            formula = current_formulae.find { |f| f[:full_name] == name }
            next unless formula

            f_deps = formula[:dependencies]
            unless formula[:poured_from_bottle?]
              f_deps += formula[:build_dependencies]
              f_deps.uniq!
            end
            next unless f_deps
            next if f_deps.empty?

            @checked_formulae_names << name
            f_deps += recursive_dependencies(current_formulae, f_deps, top_level: false)
            dependencies += f_deps
          end

          dependencies.uniq
        end

        IGNORED_TAPS = %w[homebrew/core].freeze

        def taps_to_untap(global: false, file: nil)
          @dsl ||= Brewfile.read(global:, file:)
          kept_formulae = self.kept_formulae(global:, file:).filter_map(&method(:lookup_formula))
          kept_taps = @dsl.entries.select { |e| e.type == :tap }.map(&:name)
          kept_taps += kept_formulae.filter_map(&:tap).map(&:name)
          current_taps = Homebrew::Bundle::TapDumper.tap_names
          current_taps - kept_taps - IGNORED_TAPS
        end

        def lookup_formula(formula)
          Formulary.factory(formula)
        rescue TapFormulaUnavailableError
          # ignore these as an unavailable formula implies there is no tap to worry about
          nil
        end

        def vscode_extensions_to_uninstall(global: false, file: nil)
          @dsl ||= Brewfile.read(global:, file:)
          kept_extensions = @dsl.entries.select { |e| e.type == :vscode }.map { |x| x.name.downcase }

          # To provide a graceful migration from `Brewfile`s that don't yet or
          # don't want to use `vscode`: don't remove any extensions if we don't
          # find any in the `Brewfile`.
          return [].freeze if kept_extensions.empty?

          current_extensions = Homebrew::Bundle::VscodeExtensionDumper.extensions
          current_extensions - kept_extensions
        end

        def system_output_no_stderr(cmd, *args)
          IO.popen([cmd, *args], err: :close).read
        end
      end
    end
  end
end
