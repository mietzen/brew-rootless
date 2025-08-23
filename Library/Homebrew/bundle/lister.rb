# typed: strict
# frozen_string_literal: true

module Homebrew
  module Bundle
    module Lister
      sig {
        params(entries: T::Array[Homebrew::Bundle::Dsl::Entry], formulae: T::Boolean, casks: T::Boolean,
               taps: T::Boolean, mas: T::Boolean, whalebrew: T::Boolean, vscode: T::Boolean).void
      }
      def self.list(entries, formulae:, casks:, taps:, mas:, whalebrew:, vscode:)
        entries.each do |entry|
          puts entry.name if show?(entry.type, formulae:, casks:, taps:, mas:, whalebrew:, vscode:)
        end
      end

      sig {
        params(type: Symbol, formulae: T::Boolean, casks: T::Boolean, taps: T::Boolean, mas: T::Boolean,
               whalebrew: T::Boolean, vscode: T::Boolean).returns(T::Boolean)
      }
      private_class_method def self.show?(type, formulae:, casks:, taps:, mas:, whalebrew:, vscode:)
        return true if formulae && type == :brew
        return true if casks && type == :cask
        return true if taps && type == :tap
        return true if mas && type == :mas
        return true if whalebrew && type == :whalebrew
        return true if vscode && type == :vscode

        false
      end
    end
  end
end
