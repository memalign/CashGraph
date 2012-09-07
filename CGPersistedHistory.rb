#!/usr/bin/ruby
#

require 'set'
require 'rubygems'
require 'xml/mapping'
require 'fileutils'

class CGHistory
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

    object_node :bills, "bills",
        :unmarshaller=>proc{|xml|
        set = Set.new []
        xml.each_element { |xpath|
            set << CGBill.load_from_xml(xpath)
        }
        set
    },
        :marshaller=>proc{|xml,value|
        value.each { |bill|
            e = xml.elements.add(bill.save_to_xml)
        }
    }

    object_node :userGroups, "userGroups",
        :unmarshaller=>proc{|xml|
        set = Set.new []
        xml.each_element { |xpath|
            set << CGUserGroup.load_from_xml(xpath)
        }
        set
    },
        :marshaller=>proc{|xml,value|
        value.each { |userGroup|
            e = xml.elements.add(userGroup.save_to_xml)
        }
    }

    attr_reader :users, :userGroups

    def initialize
        @users = Set.new []
        @bills = Set.new []
        @userGroups = Set.new []
    end

    def addUserGroup(userGroup)
        alreadyInSet = (@userGroups.add?(userGroup) == nil)
        puts "Tried to re-add userGroup #{userGroup} to set" unless !alreadyInSet

        # We should also probably contain all of the users in this group
        userGroup.users.each { |user|
            raise "Tried to add a userGroup with #{user} which is not contained by this CGHistory!" unless @users.include?(user)
        }
    end

    def addUser(user)
        alreadyInSet = (@users.add?(user) == nil)
        puts "Tried to re-add user #{user} to set" unless !alreadyInSet
    end

    def findUsersWithPrefixOrEmail(namePrefix, email)
        filteredUsers = Array.new

        hasFilters = false
        hasFilters ||= !email.nil?
        hasFilters ||= !namePrefix.nil?

        @users.each { |user|
            includeThisUser = !hasFilters
            includeThisUser ||= (user.email == email)
            includeThisUser ||= (!namePrefix.nil? && user.name.index(namePrefix) == 0)
            if (includeThisUser)
                filteredUsers << user
            end
        }

        return filteredUsers
    end

    def findUserGroupsWithPrefix(namePrefix)
        filteredGroups = Array.new
        @userGroups.each { |group|
            includeThisGroup ||= (!namePrefix.nil? && group.name.index(namePrefix) == 0)
            if (includeThisGroup)
                filteredGroups << group
            end
        }
        return filteredGroups 
    end

    def shuffleDebtsForGroup(group, pretend)
        if (!pretend)
            puts "Only pretend is supported for now!"
            return
        end

        # find every bill that was amongst a subset of group's users
        # Create an OweChart for these users - make OweChart filter bills based on the set of users it's constructed with
        # At the end, we can ask the owechart for reshuffled debts
        # somehow return a representation of these reshuffled debts

    end


    def addBill(bill)
        alreadyInSet = (@bills.add?(bill) == nil)
        if (!alreadyInSet && @oweChart != nil)
            @oweChart.addBill(bill)
        end
        puts "Tried to re-add bill #{bill} to set" unless !alreadyInSet
    end

    def to_s
        "Users:\n#{@users.to_a.join("\n")}\nBills:\n#{@bills.to_a.join("\n")}"
    end

    def setupOweChart
        if (@oweChart == nil)
            @oweChart = CGOweChart.new
            @bills.each { |bill|
                @oweChart.addBill(bill)
            }
        end
    end

    def oweChartForUser(user)
        if (@oweChart == nil)
            self.setupOweChart
        end

        return @oweChart.forUser(user)
    end

    def writeToFile(filename)
        # Write to file atomically
        tmpName = "#{filename}.#{Time.now.to_i}"
        File.open(tmpName, 'w') { |f|
            f.puts(self.save_to_xml)
        }
        FileUtils.cp(tmpName, filename)
        #File.rename(tmpName, filename)   #=> 0
    end
end

