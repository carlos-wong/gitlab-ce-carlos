# frozen_string_literal: true

FactoryBot.define do
  factory :upload do
    model { create(:project) }
    size { 100.kilobytes }
    uploader { "AvatarUploader" }
    mount_point { :avatar }
    secret { nil }
    store { ObjectStorage::Store::LOCAL }

    # we should build a mount agnostic upload by default
    transient do
      filename { 'avatar.jpg' }
    end

    path do
      uploader_instance = Object.const_get(uploader.to_s, false).new(model, mount_point)
      File.join(uploader_instance.store_dir, filename)
    end

    trait :personal_snippet_upload do
      model { create(:personal_snippet) }
      path { File.join(secret, filename) }
      uploader { "PersonalFileUploader" }
      secret { SecureRandom.hex }
      mount_point { nil }
    end

    trait :issuable_upload do
      uploader { "FileUploader" }
      path { File.join(secret, filename) }
      secret { SecureRandom.hex }
      mount_point { nil }
    end

    trait :with_file do
      after(:create) do |upload|
        FileUtils.mkdir_p(File.dirname(upload.absolute_path))
        FileUtils.touch(upload.absolute_path)
      end
    end

    trait :object_storage do
      store { ObjectStorage::Store::REMOTE }
    end

    trait :namespace_upload do
      model { create(:group) }
      path { File.join(secret, filename) }
      uploader { "NamespaceFileUploader" }
      secret { SecureRandom.hex }
      mount_point { nil }
    end

    trait :favicon_upload do
      model { create(:appearance) }
      uploader { "FaviconUploader" }
      secret { SecureRandom.hex }
      mount_point { :favicon }
    end

    trait :attachment_upload do
      mount_point { :attachment }
      model { create(:note) }
      uploader { "AttachmentUploader" }
    end
  end
end
