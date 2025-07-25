# typed: true # rubocop:todo Sorbet/StrictSigil
# frozen_string_literal: true

require "tab"

module Cask
  class Tab < ::AbstractTab
    sig { returns(T.nilable(T::Boolean)) }
    attr_accessor :uninstall_flight_blocks

    sig { returns(T.nilable(T::Array[T.untyped])) }
    attr_accessor :uninstall_artifacts

    sig { params(attributes: T::Hash[String, T.untyped]).void }
    def initialize(attributes = {})
      @uninstall_flight_blocks = T.let(nil, T.nilable(T::Boolean))
      @uninstall_artifacts = T.let(nil, T.nilable(T::Array[T.untyped]))

      super
    end

    # Instantiates a {Tab} for a new installation of a cask.
    sig { override.params(formula_or_cask: T.any(Formula, Cask)).returns(T.attached_class) }
    def self.create(formula_or_cask)
      cask = T.cast(formula_or_cask, Cask)
      tab = super

      tab.tabfile = cask.metadata_main_container_path/FILENAME
      tab.uninstall_flight_blocks = cask.uninstall_flight_blocks?
      tab.runtime_dependencies = Tab.runtime_deps_hash(cask)
      tab.source["version"] = cask.version.to_s
      tab.source["path"] = cask.sourcefile_path.to_s
      tab.uninstall_artifacts = cask.artifacts_list(uninstall_only: true)

      tab
    end

    # Returns a {Tab} for an already installed cask,
    # or a fake one if the cask is not installed.
    sig { params(cask: Cask).returns(T.attached_class) }
    def self.for_cask(cask)
      path = cask.metadata_main_container_path/FILENAME

      return from_file(path) if path.exist?

      tab = empty
      tab.source = {
        "path"         => cask.sourcefile_path.to_s,
        "tap"          => cask.tap&.name,
        "tap_git_head" => cask.tap_git_head,
        "version"      => cask.version.to_s,
      }
      tab.uninstall_artifacts = cask.artifacts_list(uninstall_only: true)

      tab
    end

    sig { returns(T.attached_class) }
    def self.empty
      tab = super
      tab.uninstall_flight_blocks = false
      tab.uninstall_artifacts = []
      tab.source["version"] = nil

      tab
    end

    def self.runtime_deps_hash(cask)
      cask_and_formula_dep_graph = ::Utils::TopologicalHash.graph_package_dependencies(cask)
      cask_deps, formula_deps = cask_and_formula_dep_graph.values.flatten.uniq.partition do |dep|
        dep.is_a?(Cask)
      end

      runtime_deps = {}

      if cask_deps.any?
        runtime_deps[:cask] = cask_deps.map do |dep|
          {
            "full_name"         => dep.full_name,
            "version"           => dep.version.to_s,
            "declared_directly" => cask.depends_on.cask.include?(dep.full_name),
          }
        end
      end

      if formula_deps.any?
        runtime_deps[:formula] = formula_deps.map do |dep|
          formula_to_dep_hash(dep, cask.depends_on.formula)
        end
      end

      runtime_deps
    end

    sig { returns(T.nilable(String)) }
    def version
      source["version"]
    end

    sig { params(_args: T.untyped).returns(String) }
    def to_json(*_args)
      attributes = {
        "homebrew_version"        => homebrew_version,
        "loaded_from_api"         => loaded_from_api,
        "uninstall_flight_blocks" => uninstall_flight_blocks,
        "installed_as_dependency" => installed_as_dependency,
        "installed_on_request"    => installed_on_request,
        "time"                    => time,
        "runtime_dependencies"    => runtime_dependencies,
        "source"                  => source,
        "arch"                    => arch,
        "uninstall_artifacts"     => uninstall_artifacts,
        "built_on"                => built_on,
      }

      JSON.pretty_generate(attributes)
    end

    sig { returns(String) }
    def to_s
      s = ["Installed"]
      s << "using the formulae.brew.sh API" if loaded_from_api
      s << Time.at(time).strftime("on %Y-%m-%d at %H:%M:%S") if time
      s.join(" ")
    end
  end
end
