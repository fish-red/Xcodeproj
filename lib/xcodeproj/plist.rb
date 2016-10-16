autoload :AsciiPlist, 'ascii_plist'
autoload :CFPropertyList, 'cfpropertylist'

module Xcodeproj
  # Provides support for loading and serializing property list files.
  #
  module Plist
    # @return [Hash] Returns the native objects loaded from a property list
    #         file.
    #
    # @param  [#to_s] path
    #         The path of the file.
    #
    def self.read_from_path(path)
      path = path.to_s
      unless File.exist?(path)
        raise Informative, "The plist file at path `#{path}` doesn't exist."
      end
      contents = File.read(path)
      if file_in_conflict?(contents)
        raise Informative, "The file `#{path}` is in a merge conflict."
      end
      case AsciiPlist::Reader.plist_type(contents)
      when :xml, :binary
        CFPropertyList.native_types(CFPropertyList::List.new(:data => contents).value)
      else
        AsciiPlist::Reader.new(contents).parse!.as_ruby
      end
    end

    # Serializes a hash as an XML property list file.
    #
    # @param  [#to_hash] hash
    #         The hash to store.
    #
    # @param  [#to_s] path
    #         The path of the file.
    #
    def self.write_to_path(hash, path)
      if hash.respond_to?(:to_hash)
        hash = hash.to_hash
      else
        raise TypeError, "The given `#{hash.inspect}` must respond " \
                          "to #to_hash'."
      end

      unless path.is_a?(String) || path.is_a?(Pathname)
        raise TypeError, "The given `#{path}` must be a string or 'pathname'."
      end
      path = path.to_s
      raise IOError, 'Empty path.' if path.empty?

      # create CFPropertyList::List object
      plist = CFPropertyList::List.new

      # call CFPropertyList.guess() to create corresponding CFType values
      plist.value = CFPropertyList.guess(hash)

      xml = plist.to_str(CFPropertyList::List::FORMAT_XML, :formatted => true)
      xml = reindent_xml_with_tabs(xml)
      File.open(path, 'w') do |f|
        f << xml
      end
    end

    # The known modules that can serialize plists.
    #
    KNOWN_IMPLEMENTATIONS = []

    class << self
      # @deprecated This method will be removed in 2.0
      #
      # @return [Nil]
      #
      attr_accessor :implementation
    end

    # @deprecated This method will be removed in 2.0
    #
    # @return [Nil]
    #
    def self.autoload_implementation
    end

    # @return [Bool] Checks whether there are merge conflicts in the file.
    #
    # @param  [#to_s] path
    #         The contents of the file.
    #
    def self.file_in_conflict?(contents)
      contents.match(/^(<|=|>){7}/)
    end

    def self.reindent_xml_with_tabs(xml)
      regexp = %r{
        ( # tag
          <
            (?:
              /?\w+ |
              plist\sversion="1\.0"
            )
          >\n
        )
        ([\x20]{2}+) # multiple spaces
      }mox
      xml.gsub(regexp) { Regexp.last_match(1) + "\t".*(Regexp.last_match(2).size./(2) - 1) }
    end
    private_class_method :reindent_xml_with_tabs
  end
end
