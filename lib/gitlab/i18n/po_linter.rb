# frozen_string_literal: true

module Gitlab
  module I18n
    class PoLinter
      include Gitlab::Utils::StrongMemoize

      attr_reader :po_path, :translation_entries, :metadata_entry, :locale

      VARIABLE_REGEX = /%{\w*}|%[a-z]/.freeze

      def initialize(po_path, locale = I18n.locale.to_s)
        @po_path = po_path
        @locale = locale
      end

      def errors
        @errors ||= validate_po
      end

      def validate_po
        if parse_error = parse_po
          return 'PO-syntax errors' => [parse_error]
        end

        validate_entries
      end

      def parse_po
        entries = SimplePoParser.parse(po_path)

        # The first entry is the metadata entry if there is one.
        # This is an entry when empty `msgid`
        if entries.first[:msgid].empty?
          @metadata_entry = Gitlab::I18n::MetadataEntry.new(entries.shift)
        else
          return 'Missing metadata entry.'
        end

        @translation_entries = entries.map do |entry_data|
          Gitlab::I18n::TranslationEntry.new(entry_data, metadata_entry.expected_forms)
        end

        nil
      rescue SimplePoParser::ParserError => e
        @translation_entries = []
        e.message
      end

      def validate_entries
        errors = {}

        translation_entries.each do |entry|
          errors_for_entry = validate_entry(entry)
          errors[entry.msgid] = errors_for_entry if errors_for_entry.any?
        end

        errors
      end

      def validate_entry(entry)
        errors = []

        validate_flags(errors, entry)
        validate_variables(errors, entry)
        validate_newlines(errors, entry)
        validate_number_of_plurals(errors, entry)
        validate_unescaped_chars(errors, entry)
        validate_translation(errors, entry)

        errors
      end

      def validate_unescaped_chars(errors, entry)
        if entry.msgid_contains_unescaped_chars?
          errors << 'contains unescaped `%`, escape it using `%%`'
        end

        if entry.plural_id_contains_unescaped_chars?
          errors << 'plural id contains unescaped `%`, escape it using `%%`'
        end

        if entry.translations_contain_unescaped_chars?
          errors << 'translation contains unescaped `%`, escape it using `%%`'
        end
      end

      def validate_number_of_plurals(errors, entry)
        return unless metadata_entry&.expected_forms
        return unless entry.translated?

        if entry.has_plural? && entry.all_translations.size != metadata_entry.expected_forms
          errors << "should have #{metadata_entry.expected_forms} "\
                    "#{'translations'.pluralize(metadata_entry.expected_forms)}"
        end
      end

      def validate_newlines(errors, entry)
        if entry.msgid_has_multiple_lines?
          errors << 'is defined over multiple lines, this breaks some tooling.'
        end

        if entry.plural_id_has_multiple_lines?
          errors << 'plural is defined over multiple lines, this breaks some tooling.'
        end

        if entry.translations_have_multiple_lines?
          errors << 'has translations defined over multiple lines, this breaks some tooling.'
        end
      end

      def validate_variables(errors, entry)
        if entry.has_singular_translation?
          validate_variables_in_message(errors, entry.msgid, entry.msgid)

          validate_variables_in_message(errors, entry.msgid, entry.singular_translation)
        end

        if entry.has_plural?
          validate_variables_in_message(errors, entry.plural_id, entry.plural_id)

          entry.plural_translations.each do |translation|
            validate_variables_in_message(errors, entry.plural_id, translation)
          end
        end
      end

      def validate_variables_in_message(errors, message_id, message_translation)
        required_variables = message_id.scan(VARIABLE_REGEX)

        validate_unnamed_variables(errors, required_variables)
        validate_variable_usage(errors, message_translation, required_variables)
      end

      def validate_translation(errors, entry)
        Gitlab::I18n.with_locale(locale) do
          if entry.has_plural?
            translate_plural(entry)
          else
            translate_singular(entry)
          end
        end

      # `sprintf` could raise an `ArgumentError` when invalid passing something
      # other than a Hash when using named variables
      #
      # `sprintf` could raise `TypeError` when passing a wrong type when using
      # unnamed variables
      #
      # FastGettext::Translation could raise `RuntimeError` (raised as a string),
      # or as subclassess `NoTextDomainConfigured` & `InvalidFormat`
      #
      # `FastGettext::Translation` could raise `ArgumentError` as subclassess
      # `InvalidEncoding`, `IllegalSequence` & `InvalidCharacter`
      rescue ArgumentError, TypeError, RuntimeError => e
        errors << "Failure translating to #{locale}: #{e.message}"
      end

      def translate_singular(entry)
        used_variables = entry.msgid.scan(VARIABLE_REGEX)
        variables = fill_in_variables(used_variables)

        translation = if entry.msgid.include?('|')
                        FastGettext::Translation.s_(entry.msgid)
                      else
                        FastGettext::Translation._(entry.msgid)
                      end

        translation % variables if used_variables.any?
      end

      def translate_plural(entry)
        numbers_covering_all_plurals.map do |number|
          translation = FastGettext::Translation.n_(entry.msgid, entry.plural_id, number)
          index = index_for_pluralization(number)
          used_variables = index == 0 ? entry.msgid.scan(VARIABLE_REGEX) : entry.plural_id.scan(VARIABLE_REGEX)
          variables = fill_in_variables(used_variables)

          translation % variables if variables.any?
        end
      end

      def numbers_covering_all_plurals
        @numbers_covering_all_plurals ||= calculate_numbers_covering_all_plurals
      end

      def calculate_numbers_covering_all_plurals
        required_numbers = []
        discovered_indexes = []
        counter = 0

        while discovered_indexes.size < metadata_entry.forms_to_test && counter < Gitlab::I18n::MetadataEntry::MAX_FORMS_TO_TEST
          index_for_count = index_for_pluralization(counter)

          unless discovered_indexes.include?(index_for_count)
            discovered_indexes << index_for_count
            required_numbers << counter
          end

          counter += 1
        end

        required_numbers
      end

      def index_for_pluralization(counter)
        # This calls the C function that defines the pluralization rule, it can
        # return a boolean (`false` represents 0, `true` represents 1) or an integer
        # that specifies the plural form to be used for the given number
        pluralization_result = Gitlab::I18n.with_locale(locale) do
          FastGettext.pluralisation_rule.call(counter)
        end

        case pluralization_result
        when false
          0
        when true
          1
        else
          pluralization_result
        end
      end

      def fill_in_variables(variables)
        if variables.empty?
          []
        elsif variables.any? { |variable| unnamed_variable?(variable) }
          variables.map do |variable|
            variable == '%d' ? Random.rand(1000) : Gitlab::Utils.random_string
          end
        else
          variables.inject({}) do |hash, variable|
            variable_name = variable[/\w+/]
            hash[variable_name] = Gitlab::Utils.random_string
            hash
          end
        end
      end

      def validate_unnamed_variables(errors, variables)
        unnamed_variables, named_variables = variables.partition { |name| unnamed_variable?(name) }

        if unnamed_variables.any? && named_variables.any?
          errors << 'is combining named variables with unnamed variables'
        end

        if unnamed_variables.size > 1
          errors << 'is combining multiple unnamed variables'
        end
      end

      def validate_variable_usage(errors, translation, required_variables)
        # We don't need to validate when the message is empty.
        # In this case we fall back to the default, which has all the
        # required variables.
        return if translation.empty?

        found_variables = translation.scan(VARIABLE_REGEX)

        missing_variables = required_variables - found_variables
        if missing_variables.any?
          errors << "<#{translation}> is missing: [#{missing_variables.to_sentence}]"
        end

        unknown_variables = found_variables - required_variables
        if unknown_variables.any?
          errors << "<#{translation}> is using unknown variables: [#{unknown_variables.to_sentence}]"
        end
      end

      def unnamed_variable?(variable_name)
        !variable_name.start_with?('%{')
      end

      def validate_flags(errors, entry)
        errors << "is marked #{entry.flag}" if entry.flag
      end
    end
  end
end
