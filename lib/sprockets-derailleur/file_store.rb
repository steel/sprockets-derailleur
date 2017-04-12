# The Sprockets::Cache::FileStore is not thread/parallel safe.
# This one uses file locks to be safe.
module SprocketsDerailleur
  class FileStore < Sprockets::Cache::FileStore
    prepend SprocketsDerailleur::FileStoreExtension
  end
end
