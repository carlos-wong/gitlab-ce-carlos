# frozen_string_literal: true

module Gitlab
  module Ci
    module Ansi2json
      # Line class is responsible for keeping the internal state of
      # a log line and to finally serialize it as Hash.
      class Line
        # Line::Segment is a portion of a line that has its own style
        # and text. Multiple segments make the line content.
        class Segment
          attr_accessor :text, :style

          def initialize(style:)
            @text = +''
            @style = style
          end

          def empty?
            text.empty?
          end

          def to_h
            # Without force encoding to UTF-8 we could get an error
            # when serializing the Hash to JSON.
            # Encoding::UndefinedConversionError:
            #   "\xE2" from ASCII-8BIT to UTF-8
            { text: text.force_encoding('UTF-8') }.tap do |result|
              result[:style] = style.to_s if style.set?
            end
          end
        end

        attr_reader :offset, :sections, :segments, :current_segment,
                    :section_header, :section_duration

        def initialize(offset:, style:, sections: [])
          @offset = offset
          @segments = []
          @sections = sections
          @section_header = false
          @duration = nil
          @current_segment = Segment.new(style: style)
        end

        def <<(data)
          @current_segment.text << data
        end

        def style
          @current_segment.style
        end

        def empty?
          @segments.empty? && @current_segment.empty?
        end

        def update_style(ansi_commands)
          @current_segment.style.update(ansi_commands)
        end

        def add_section(section)
          @sections << section
        end

        def set_as_section_header
          @section_header = true
        end

        def set_section_duration(duration)
          @section_duration = Time.at(duration.to_i).strftime('%M:%S')
        end

        def flush_current_segment!
          return if @current_segment.empty?

          @segments << @current_segment.to_h
          @current_segment = Segment.new(style: @current_segment.style)
        end

        def to_h
          flush_current_segment!

          { offset: offset, content: @segments }.tap do |result|
            result[:section] = sections.last if sections.any?
            result[:section_header] = true if @section_header
            result[:section_duration] = @section_duration if @section_duration
          end
        end
      end
    end
  end
end
