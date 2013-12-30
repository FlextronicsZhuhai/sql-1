# encoding: utf-8

module SQL
  module Generator
    class Emitter

      # Update statement emitter
      class Update < self
        COMMAND = K_UPDATE

        handle :update

        children :from, :assignment, :where

      private

        # @see Emitter#dispatch
        #
        # @return [undefined]
        #
        # @api private
        def dispatch
          write_command(from)
          write_node(assignment, K_SET)
          write_node(where,      K_WHERE)
        end

      end # Update
    end # Emitter
  end # Generator
end # SQL
