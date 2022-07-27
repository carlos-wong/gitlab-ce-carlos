# frozen_string_literal: true

module Packages
  module Debian
    class GenerateDistributionService
      include Gitlab::Utils::StrongMemoize
      include ::Packages::FIPS
      include ExclusiveLeaseGuard

      ONE_HOUR = 1.hour.freeze

      # used by ExclusiveLeaseGuard
      DEFAULT_LEASE_TIMEOUT = 1.hour.to_i.freeze

      # From https://salsa.debian.org/ftp-team/dak/-/blob/991aaa27a7f7aa773bb9c0cf2d516e383d9cffa0/setup/core-init.d/080_metadatakeys#L9
      METADATA_KEYS = %w(
        Package
        Source
        Binary
        Version
        Essential
        Installed-Size
        Maintainer
        Uploaders
        Original-Maintainer
        Build-Depends
        Build-Depends-Indep
        Build-Conflicts
        Build-Conflicts-Indep
        Architecture
        Standards-Version
        Format
        Files
        Dm-Upload-Allowed
        Vcs-Browse
        Vcs-Hg
        Vcs-Darcs
        Vcs-Svn
        Vcs-Git
        Vcs-Browser
        Vcs-Arch
        Vcs-Bzr
        Vcs-Mtn
        Vcs-Cvs
        Checksums-Sha256
        Checksums-Sha1
        Replaces
        Provides
        Depends
        Pre-Depends
        Recommends
        Suggests
        Enhances
        Conflicts
        Breaks
        Description
        Origin
        Bugs
        Multi-Arch
        Homepage
        Tag
        Package-Type
        Installer-Menu-Item
      ).freeze

      def initialize(distribution)
        @distribution = distribution
        @oldest_kept_generated_at = nil
        @md5sum = []
        @sha256 = []
      end

      def execute
        raise DisabledError, 'Debian registry is not FIPS compliant' if Gitlab::FIPS.enabled?

        try_obtain_lease do
          @distribution.transaction do
            # We consider `apt-get update` can take at most one hour
            # We keep all generations younger than one hour
            # and the previous generation
            @oldest_kept_generated_at = @distribution.component_files.updated_before(release_date - ONE_HOUR).maximum(:updated_at)
            generate_component_files
            generate_release
            destroy_old_component_files
          end
        end
      end

      private

      def generate_component_files
        @distribution.components.ordered_by_name.each do |component|
          @distribution.architectures.ordered_by_name.each do |architecture|
            generate_component_file(component, :packages, architecture, :deb)
            generate_component_file(component, :di_packages, architecture, :udeb)
          end
          generate_component_file(component, :sources, nil, :dsc)
        end
      end

      def generate_component_file(component, component_file_type, architecture, package_file_type)
        paragraphs = @distribution.package_files
                                  .preload_package
                                  .preload_debian_file_metadata
                                  .with_debian_component_name(component.name)
                                  .with_debian_architecture_name(architecture&.name)
                                  .with_debian_file_type(package_file_type)
                                  .find_each
                                  .map(&method(:package_stanza_from_fields))
        reuse_or_create_component_file(component, component_file_type, architecture, paragraphs.join("\n"))
      end

      def package_stanza_from_fields(package_file)
        [
          METADATA_KEYS.map do |metadata_key|
            metadata_name = metadata_key
            metadata_value = package_file.debian_fields[metadata_key]

            if package_file.debian_dsc?
              metadata_name = 'Package' if metadata_key == 'Source'
              checksum = case metadata_key
                         when 'Files' then package_file.file_md5
                         when 'Checksums-Sha256' then package_file.file_sha256
                         when 'Checksums-Sha1' then package_file.file_sha1
                         end

              if checksum
                metadata_value = "\n#{checksum} #{package_file.size} #{package_file.file_name}#{metadata_value}"
              end
            end

            rfc822_field(metadata_name, metadata_value)
          end,
          rfc822_field('Section', package_file.debian_fields['Section'] || 'misc'),
          rfc822_field('Priority', package_file.debian_fields['Priority'] || 'extra'),
          package_file_extra_fields(package_file)
        ].flatten.compact.join('')
      end

      def package_file_extra_fields(package_file)
        if package_file.debian_dsc?
          [
            rfc822_field('Directory', package_dirname(package_file))
          ]
        else
          [
            rfc822_field('Filename', "#{package_dirname(package_file)}/#{package_file.file_name}"),
            rfc822_field('Size', package_file.size),
            rfc822_field('MD5sum', package_file.file_md5),
            rfc822_field('SHA256', package_file.file_sha256)
          ]
        end
      end

      def package_dirname(package_file)
        letter = package_file.package.name.start_with?('lib') ? package_file.package.name[0..3] : package_file.package.name[0]
        "#{pool_prefix(package_file)}/#{letter}/#{package_file.package.name}/#{package_file.package.version}"
      end

      def pool_prefix(package_file)
        case @distribution
        when ::Packages::Debian::GroupDistribution
          "pool/#{@distribution.codename}/#{package_file.package.project_id}"
        else
          "pool/#{@distribution.codename}"
        end
      end

      def reuse_or_create_component_file(component, component_file_type, architecture, content)
        file_md5 = Digest::MD5.hexdigest(content)
        file_sha256 = Digest::SHA256.hexdigest(content)
        component_file = component.files
                                  .with_file_type(component_file_type)
                                  .with_architecture(architecture)
                                  .with_compression_type(nil)
                                  .with_file_sha256(file_sha256)
                                  .last

        if component_file
          component_file.touch(time: release_date)
        else
          component_file = component.files.create!(
            updated_at: release_date,
            file_type: component_file_type,
            architecture: architecture,
            compression_type: nil,
            file: CarrierWaveStringFile.new(content),
            file_md5: file_md5,
            file_sha256: file_sha256
          )
        end

        @md5sum.append(" #{file_md5} #{component_file.size.to_s.rjust(8)} #{component_file.relative_path}")
        @sha256.append(" #{file_sha256} #{component_file.size.to_s.rjust(8)} #{component_file.relative_path}")
      end

      def generate_release
        @distribution.key || @distribution.create_key(GenerateDistributionKeyService.new.execute)
        @distribution.file = CarrierWaveStringFile.new(release_content)
        @distribution.file_signature = SignDistributionService.new(@distribution, release_content, detach: true).execute
        @distribution.signed_file = CarrierWaveStringFile.new(
          SignDistributionService.new(@distribution, release_content).execute
        )
        @distribution.updated_at = release_date
        @distribution.save!
      end

      def release_content
        strong_memoize(:release_content) do
          release_header + release_sums
        end
      end

      def release_header
        [
          %w[origin label suite version codename].map do |attribute|
            rfc822_field(attribute.capitalize, @distribution.attributes[attribute])
          end,
          rfc822_field('Date', release_date.to_formatted_s(:rfc822)),
          valid_until_field,
          rfc822_field('NotAutomatic', !@distribution.automatic, !@distribution.automatic),
          rfc822_field('ButAutomaticUpgrades', @distribution.automatic_upgrades, !@distribution.automatic && @distribution.automatic_upgrades),
          rfc822_field('Architectures', @distribution.architectures.map { |architecture| architecture.name }.sort.join(' ')),
          rfc822_field('Components', @distribution.components.map { |component| component.name }.sort.join(' ')),
          rfc822_field('Description', @distribution.description)
        ].flatten.compact.join('')
      end

      def release_date
        strong_memoize(:release_date) do
          Time.now.utc
        end
      end

      def release_sums
        ["MD5Sum:", @md5sum, "SHA256:", @sha256].flatten.compact.join("\n") + "\n"
      end

      def rfc822_field(name, value, condition = true)
        return unless condition
        return if value.blank?

        value = " #{value}" unless value[0] == "\n"
        "#{name}:#{value.to_s.gsub("\n\n", "\n.\n").gsub("\n", "\n ")}\n"
      end

      def valid_until_field
        return unless @distribution.valid_time_duration_seconds

        rfc822_field('Valid-Until', release_date.since(@distribution.valid_time_duration_seconds).to_formatted_s(:rfc822))
      end

      def destroy_old_component_files
        return if @oldest_kept_generated_at.nil?

        @distribution.component_files.updated_before(@oldest_kept_generated_at).destroy_all # rubocop:disable Cop/DestroyAll
      end

      # used by ExclusiveLeaseGuard
      def lease_key
        "packages:debian:generate_distribution_service:distribution:#{@distribution.id}"
      end

      # used by ExclusiveLeaseGuard
      def lease_timeout
        DEFAULT_LEASE_TIMEOUT
      end
    end
  end
end
