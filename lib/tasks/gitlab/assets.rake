namespace :gitlab do
  namespace :assets do
    desc 'GitLab | Assets | Compile all frontend assets'
    task :compile do
      require_dependency 'gitlab/task_helpers'

      %w[
        yarn:check
        gettext:po_to_json
        rake:assets:precompile
        webpack:compile
        gitlab:assets:fix_urls
      ].each(&Gitlab::TaskHelpers.method(:invoke_and_time_task))
    end

    desc 'GitLab | Assets | Clean up old compiled frontend assets'
    task clean: ['rake:assets:clean']

    desc 'GitLab | Assets | Remove all compiled frontend assets'
    task purge: ['rake:assets:clobber']

    desc 'GitLab | Assets | Uninstall frontend dependencies'
    task purge_modules: ['yarn:clobber']

    desc 'GitLab | Assets | Fix all absolute url references in CSS'
    task :fix_urls do
      css_files = Dir['public/assets/*.css']
      css_files.each do |file|
        # replace url(/assets/*) with url(./*)
        puts "Fixing #{file}"
        system "sed", "-i", "-e", 's/url(\([\"\']\?\)\/assets\//url(\1.\//g', file

        # rewrite the corresponding gzip file (if it exists)
        gzip = "#{file}.gz"
        if File.exist?(gzip)
          puts "Fixing #{gzip}"

          FileUtils.rm(gzip)
          mtime = File.stat(file).mtime

          File.open(gzip, 'wb+') do |f|
            gz = Zlib::GzipWriter.new(f, Zlib::BEST_COMPRESSION)
            gz.mtime = mtime
            gz.write IO.binread(file)
            gz.close

            File.utime(mtime, mtime, f.path)
          end
        end
      end
    end

    desc 'GitLab | Assets | Compile vendor assets'
    task :vendor do
      unless system('yarn webpack-vendor')
        abort 'Error: Unable to compile webpack DLL.'.color(:red)
      end
    end
  end
end
