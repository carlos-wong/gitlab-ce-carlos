# frozen_string_literal: true

module Mutations
  module Notes
    module Update
      class ImageDiffNote < Mutations::Notes::Update::Base
        graphql_name 'UpdateImageDiffNote'

        argument :body,
                  GraphQL::STRING_TYPE,
                  required: false,
                  description: copy_field_description(Types::Notes::NoteType, :body)

        argument :position,
                  Types::Notes::UpdateDiffImagePositionInputType,
                  required: false,
                  description: copy_field_description(Types::Notes::NoteType, :position)

        def ready?(**args)
          # As both arguments are optional, validate here that one of the
          # arguments are present.
          #
          # This may be able to be done using InputUnions in the future
          # if this RFC is merged:
          # https://github.com/graphql/graphql-spec/blob/master/rfcs/InputUnion.md
          if args.values_at(:body, :position).compact.blank?
            raise Gitlab::Graphql::Errors::ArgumentError,
                  'body or position arguments are required'
          end

          super(args)
        end

        private

        def pre_update_checks!(note, args)
          unless note.is_a?(DiffNote) && note.position.on_image?
            raise Gitlab::Graphql::Errors::ResourceNotAvailable,
                  'Resource is not an ImageDiffNote'
          end
        end

        def note_params(note, args)
          super(note, args).merge(
            position: position_params(note, args)
          ).compact
        end

        def position_params(note, args)
          new_position = args[:position]&.to_h&.compact
          return unless new_position

          original_position = note.position.to_h

          Gitlab::Diff::Position.new(original_position.merge(new_position))
        end
      end
    end
  end
end
