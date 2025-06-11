# typed: strict
# frozen_string_literal: true

module OS
  module Mac
    module DevCmd
      module Tests
        extend T::Helpers

        requires_ancestor { Homebrew::DevCmd::Tests }

        private

        sig { params(bundle_args: T::Array[String]).returns(T::Array[String]) }
        def os_bundle_args(bundle_args)
          non_linux_bundle_args(bundle_args)
        end
      end
    end
  end
end

Homebrew::DevCmd::Tests.prepend(OS::Mac::DevCmd::Tests)
