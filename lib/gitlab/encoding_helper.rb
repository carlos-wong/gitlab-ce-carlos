# frozen_string_literal: true

module Gitlab
  module EncodingHelper
    extend self

    # This threshold is carefully tweaked to prevent usage of encodings detected
    # by CharlockHolmes with low confidence. If CharlockHolmes confidence is low,
    # we're better off sticking with utf8 encoding.
    # Reason: git diff can return strings with invalid utf8 byte sequences if it
    # truncates a diff in the middle of a multibyte character. In this case
    # CharlockHolmes will try to guess the encoding and will likely suggest an
    # obscure encoding with low confidence.
    # There is a lot more info with this merge request:
    # https://gitlab.com/gitlab-org/gitlab_git/merge_requests/77#note_4754193
    ENCODING_CONFIDENCE_THRESHOLD = 50

    UNICODE_REPLACEMENT_CHARACTER = "�"

    def encode!(message)
      message = force_encode_utf8(message)
      return message if message.valid_encoding?

      # return message if message type is binary
      detect = detect_encoding(message)
      return message.force_encoding("BINARY") if detect_binary?(message, detect)

      if detect && detect[:encoding] && detect[:confidence] > ENCODING_CONFIDENCE_THRESHOLD
        # force detected encoding if we have sufficient confidence.
        message.force_encoding(detect[:encoding])
      end

      # encode and clean the bad chars
      message.replace clean(message)
    rescue ArgumentError => e
      return unless e.message.include?('unknown encoding name')

      encoding = detect ? detect[:encoding] : "unknown"
      "--broken encoding: #{encoding}"
    end

    def detect_encoding(data, limit: CharlockHolmes::EncodingDetector::DEFAULT_BINARY_SCAN_LEN, cache_key: nil)
      return if data.nil?

      CharlockHolmes::EncodingDetector.new(limit).detect(data)
    end

    def detect_binary?(data, detect = nil)
      detect ||= detect_encoding(data)
      detect && detect[:type] == :binary && detect[:confidence] == 100
    end

    # EncodingDetector checks the first 1024 * 1024 bytes for NUL byte, libgit2 checks
    # only the first 8000 (https://github.com/libgit2/libgit2/blob/2ed855a9e8f9af211e7274021c2264e600c0f86b/src/filter.h#L15),
    # which is what we use below to keep a consistent behavior.
    def detect_libgit2_binary?(data, cache_key: nil)
      detect = detect_encoding(data, limit: 8000, cache_key: cache_key)
      detect && detect[:type] == :binary
    end

    # This is like encode_utf8 except we skip autodetection of the encoding. We
    # assume the data must be interpreted as UTF-8.
    def encode_utf8_no_detect(message)
      message = force_encode_utf8(message)
      return message if message.valid_encoding?

      message.encode(Encoding::UTF_8, invalid: :replace, undef: :replace)
    end

    def encode_utf8_with_replacement_character(data)
      encode_utf8(data, replace: UNICODE_REPLACEMENT_CHARACTER)
    end

    def encode_utf8(message, replace: "")
      message = force_encode_utf8(message)
      return message if message.valid_encoding?

      detect = detect_encoding(message)

      if detect && detect[:encoding]
        begin
          CharlockHolmes::Converter.convert(message, detect[:encoding], 'UTF-8')
        rescue ArgumentError => e
          Gitlab::AppLogger.warn("Ignoring error converting #{detect[:encoding]} into UTF8: #{e.message}")

          ''
        end
      else
        clean(message, replace: replace)
      end
    rescue ArgumentError
      nil
    end

    def encode_binary(str)
      return "" if str.nil?

      str.dup.force_encoding(Encoding::ASCII_8BIT)
    end

    def binary_io(str_or_io)
      io = str_or_io.to_io.dup if str_or_io.respond_to?(:to_io)
      io ||= StringIO.new(str_or_io.to_s.freeze)

      io.tap { |io| io.set_encoding(Encoding::ASCII_8BIT) }
    end

    ESCAPED_CHARS = {
      "a" => "\a", "b" => "\b", "e" => "\e", "f" => "\f",
      "n" => "\n", "r" => "\r", "t" => "\t", "v" => "\v",
      "\"" => "\""
    }.freeze

    # rubocop:disable Style/AsciiComments
    # `unquote_path` decode filepaths that are returned by some git commands.
    # The path may be returned in double-quotes if it contains special characters,
    # that are encoded in octal. Also, some characters (see `ESCAPED_CHARS`) are escaped.
    # eg. "\311\240\304\253\305\247\305\200\310\247\306\200" (quotes included) is decoded as ɠīŧŀȧƀ
    #
    # Based on `unquote_c_style` from git source
    # https://github.com/git/git/blob/v2.35.1/quote.c#L399
    # rubocop:enable Style/AsciiComments
    def unquote_path(filename)
      return filename unless filename[0] == '"'

      filename = filename[1..-2].gsub(/\\(?:([#{ESCAPED_CHARS.keys.join}\\])|(\d{3}))/) do
        if c = Regexp.last_match(1)
          c == "\\" ? "\\" : ESCAPED_CHARS[c]
        elsif c = Regexp.last_match(2)
          c.to_i(8).chr
        end
      end

      filename.force_encoding("UTF-8")
    end

    private

    def force_encode_utf8(message)
      raise ArgumentError unless message.respond_to?(:force_encoding)
      return message if message.encoding == Encoding::UTF_8 && message.valid_encoding?

      message = message.dup if message.respond_to?(:frozen?) && message.frozen?

      message.force_encoding("UTF-8")
    end

    def clean(message, replace: "")
      message.encode(
        "UTF-16BE",
        undef: :replace,
        invalid: :replace,
        replace: replace.encode("UTF-16BE")
      )
        .encode("UTF-8")
        .gsub("\0".encode("UTF-8"), "")
    end
  end
end
