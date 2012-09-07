#!/usr/bin/ruby
#

require 'rubygems'
require 'xml/mapping'

class CGUser
    attr_reader :uuid, :email

    include XML::Mapping

    text_node :name, "@name"
    text_node :email, "@email"
    text_node :uuid, "@uuid"

    def initialize(prettyName, emailAddress)
        @name = prettyName
        @email = emailAddress
        @uuid = `uuidgen`.strip
    end

    def to_s
        "CGUser(name:#{@name} email:#{@email} uuid:#{@uuid})"
    end

    def hash
        @uuid.tr("-", '').hex
    end

    def eql?(other)
        return @uuid == other.uuid
    end
end
