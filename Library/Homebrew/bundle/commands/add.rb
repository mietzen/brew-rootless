# typed: true # rubocop:todo Sorbet/StrictSigil
# frozen_string_literal: true

module Homebrew
  module Bundle
    module Commands
      module Add
        def self.run(*args, type:, global:, file:)
          Homebrew::Bundle::Adder.add(*args, type:, global:, file:)
        end
      end
    end
  end
end
