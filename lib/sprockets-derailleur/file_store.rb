require 'fileutils'
require 'timeout'

# The Sprockets::Cache::FileStore is not thread/parallel safe.
# This one uses file locks to be safe.
module SprocketsDerailleur
  class FileStore < Sprockets::Cache::FileStore
    def lock
      @lock ||= begin
        FileUtils.mkdir_p @root
        File.open(@root.join("lock"), File::RDWR|File::CREAT)
      end
    end

    # Lookup value in cache
    def [](key)
      with_lock(File::LOCK_SH) { super }
    end

    # Save value to cache
    def []=(key, value)
      with_lock(File::LOCK_EX) { super }
    end

    def with_lock(type)
      Timeout::timeout(1) { lock.flock(type) }
      yield
    ensure
      lock.flock(File::LOCK_UN)
    end
  end
end
