require "sprockets-derailleur/version"
require "sprockets"

module Sprockets
  class Manifest
    attr_reader :workers
    
    alias_method :old_initialize, :initialize
    def initialize(environment, path, workers=1)
      @workers = workers
      old_initialize(environment, path)
    end

    alias_method :compile_with_workers, :compile
    def compile(*args)
      time = Benchmark.measure do
        paths = environment.each_logical_path(*args).to_a +
          args.flatten.select { |fn| Pathname.new(fn).absolute? if fn.is_a?(String)}

        logger.warn "Initializing #{@workers} workers"

        workers = []
        @workers.times do
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
              if asset = find_asset(path)
                data = {'assets' => {}, 'files' => {}}

                data['files'][asset.digest_path] = {
                  'logical_path' => asset.logical_path,
                  'mtime'        => asset.mtime.iso8601,
                  'size'         => asset.bytesize,
                  'digest'       => asset.digest
                }
                data['assets'][asset.logical_path] = asset.digest_path

                target = File.join(dir, asset.digest_path)

                if File.exist?(target)
                  logger.debug "Skipping #{target}, already exists"
                else
                  logger.debug "Writing #{target}"
                  asset.write_to target
                end

                Marshal.dump(data, child_write)
              end
            end
            logger.warn "Compiled #{path} (#{(time.real * 1000).round}ms)"
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