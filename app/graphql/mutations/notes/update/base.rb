# frozen_string_literal: true

module Mutations
  module Notes
    module Update
      # This is a Base class for the Note update mutations and is not
      # mounted as a GraphQL mutation itself.
      class Base < Mutations::Notes::Base
        authorize :admin_note

        argument :id,
                  GraphQL::ID_TYPE,
                  required: true,
                  description: 'The global id of the note to update'

        def resolve(args)
          note = authorized_find!(id: args[:id])

          pre_update_checks!(note, args)

          updated_note = ::Notes::UpdateService.new(
            note.project,
            current_user,
            note_params(note, args)
          ).execute(note)

          # It's possible for updated_note to be `nil`, in the situation
          # where the note is deleted within `Notes::UpdateService` due to
          # the body of the note only containing Quick Actions.
          {
            note: updated_note&.reset,
            errors: updated_note ? errors_on_object(updated_note) : []
          }
        end

        private

        def pre_update_checks!(_note, _args)
          raise NotImplementedError
        end

        def note_params(_note, args)
          { note: args[:body] }.compact
        end
      end
    end
  end
end
