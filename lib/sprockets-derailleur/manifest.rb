require "sprockets"

module Sprockets
  class Manifest
    alias_method :compile_with_workers, :compile
    def compile(*args)
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

              if asset = find_asset(path)

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
                  logger.debug "Writing #{target}"
                  asset.write_to target
                  asset.write_to "#{target}.gz" if asset.is_a?(BundledAsset)
                end

                Marshal.dump(data, child_write)
              else
                data['errors'][path] = "Not found"
                Marshal.dump(data, child_write)
              end
            end

            logger.warn "Compiled #{path} (#{(time.real * 1000).round}ms, pid #{Process.pid})"
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
  end
end
