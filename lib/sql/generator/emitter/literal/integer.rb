module SQL
  module Generator
    class Emitter
      class Literal

        # Literal integer emitter base class
        class Integer < self

          handle :integer

        private

          def dispatch
            write(first_child.to_s)
          end

        end # String

      end # Literal
    end # Emitter
  end # Generator
end # SQL