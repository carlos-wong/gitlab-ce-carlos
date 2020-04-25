# frozen_string_literal: true

FactoryBot.define do
  factory :diff_position, class: 'Gitlab::Diff::Position' do
    skip_create # non-model factories (i.e. without #save)

    transient do
      file { 'path/to/file' }

      # Allow diff to be passed as a single object.
      diff_refs do
        ::Gitlab::Diff::DiffRefs.new(
          base_sha: Digest::SHA1.hexdigest(SecureRandom.hex),
          head_sha: Digest::SHA1.hexdigest(SecureRandom.hex),
          start_sha: Digest::SHA1.hexdigest(SecureRandom.hex)
        )
      end
    end

    old_path { file }
    new_path { file }

    base_sha  { diff_refs&.base_sha }
    head_sha  { diff_refs&.head_sha }
    start_sha { diff_refs&.start_sha }

    initialize_with { new(attributes) }

    trait :moved do
      new_path { 'path/to/new.file' }
    end

    factory :text_diff_position do
      position_type { 'text' }
      old_line { 10 }
      new_line { 10 }

      trait :added do
        old_line { nil }
      end
    end

    factory :image_diff_position do
      position_type { 'image' }
      x { 1 }
      y { 1 }
      width { 10 }
      height { 10 }
    end
  end
end
