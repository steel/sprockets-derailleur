require "sprockets"

module Sprockets
  class Manifest
    alias_method :compile_with_workers, :compile
    def compile(*args)
      SprocketsDerailleur::prepend_file_store_if_required

      worker_count = SprocketsDerailleur::worker_count
      paths_with_errors = {}

      time = Benchmark.measure do
        paths = environment.each_logical_path(*args).to_a +
          args.flatten.select { |fn| Pathname.new(fn).absolute? if fn.is_a?(String)}

        # Skip all files without extensions, see
        # https://github.com/sstephenson/sprockets/issues/347 for more info
        paths = paths.select do |path|

          if File.extname(path) == ""
            logger.info "Skipping #{path} since it has no extension"
            false
          else
            true
          end
        end

        logger.warn "Initializing #{worker_count} workers"

        workers = []
        worker_count.times do
          workers << worker(paths)
        end

        reads = workers.map{|worker| worker[:read]}
        writes = workers.map{|worker| worker[:write]}

        index = 0
        finished = 0

        loop do
          break if finished >= paths.size

          ready = IO.select(reads, writes)

          ready[0].each do |readable|
            data = Marshal.load(readable)
            assets.merge! data["assets"]
            files.merge! data["files"]
            paths_with_errors.merge! data["errors"]

            finished += 1
          end

          ready[1].each do |write|
            break if index >= paths.size

            Marshal.dump(index, write)
            index += 1
          end
        end

        logger.debug "Cleaning up workers"

        workers.each do |worker|
          worker[:read].close
          worker[:write].close
        end

        workers.each do |worker|
          Process.wait worker[:pid]
        end

        save
      end

      logger.warn "Completed compiling assets (#{(time.real * 100).round / 100.0}s)"

      unless paths_with_errors.empty?
        logger.warn "Asset paths with errors:"

        paths_with_errors.each do |path, message|
          logger.warn "\t#{path}: #{message}"
        end
      end
    end

    def worker(paths)
      child_read, parent_write = IO.pipe
      parent_read, child_write = IO.pipe

      pid = fork do
        begin
          parent_write.close
          parent_read.close

          while !child_read.eof?
            path = paths[Marshal.load(child_read)]

            time = Benchmark.measure do
              data = {'assets' => {}, 'files' => {}, 'errors' => {}}

              version_agnostic_find(path).each do |asset|
                data['files'][asset.digest_path] = {
                  'logical_path' => asset.logical_path,
                  'mtime'        => asset.mtime.iso8601,
                  'size'         => asset.length,
                  'digest'       => asset.digest
                }
                data['assets'][asset.logical_path] = asset.digest_path

                target = File.join(dir, asset.digest_path)

                if File.exist?(target)
                  logger.debug "Skipping #{target}, already exists"
                else
                  logger.info "Writing #{target}"
                  asset.write_to target
                  asset.write_to "#{target}.gz" unless skip_gzip?(asset)
                end

                Marshal.dump(data, child_write)
              end
            end

            if SprocketsDerailleur.configuration.warn_compile_times
              logger.warn "Compiled #{path} (#{(time.real * 1000).round}ms, pid #{Process.pid})"
            else
              logger.debug "Compiled #{path} (#{(time.real * 1000).round}ms, pid #{Process.pid})"
            end
          end
        ensure
          child_read.close
          child_write.close
        end
      end

      child_read.close
      child_write.close

      {:read => parent_read, :write => parent_write, :pid => pid}
    end

    private

    def version_agnostic_find(*args)
      if sprockets2?
        [find_asset(*args)].each
      else
        find(*args)
      end
    end

    def sprockets2?
      Sprockets::VERSION.start_with?('2')
    end

    def skip_gzip?(asset)
      if sprockets2?
        asset.is_a?(BundledAsset)
      else
        environment.skip_gzip?
      end
    end
  end
end
