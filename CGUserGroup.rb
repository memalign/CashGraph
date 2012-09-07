#!/usr/bin/ruby
#

require 'set'
require 'rubygems'
require 'xml/mapping'

class CGUserGroup
    include XML::Mapping

    object_node :users, "users",
        :unmarshaller=>proc{|xml|
        set = Set.new []
        xml.each_element { |xpath|
            set << CGUser.load_from_xml(xpath)
        }
        set
    },
        :marshaller=>proc{|xml,value|
        value.each { |user|
            e = xml.elements.add(user.save_to_xml)
        }
    }

    text_node :name, "@name"
    text_node :uuid, "@uuid"

    attr_reader :users, :name

    def initialize(name)
        self.initialize(name, [])
    end

    # users is an array
    def initialize(name, users)
        @name = name
        @users = Set.new users
        @uuid = `uuidgen`.strip
    end

    def hash
        @uuid.tr("-", '').hex
    end

    def eql?(other)
        return @uuid == other.uuid
    end
end

