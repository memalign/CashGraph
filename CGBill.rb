#!/usr/bin/ruby
#

require 'bigdecimal'
require 'CGUser'

class CGParticipantPayTriple
    include XML::Mapping

    object_node :user, "CGUser", :class=>CGUser
    object_node :amountOwe, "amountOwe", :class=>BigDecimal
    object_node :amountPaid, "amountPaid", :class=>BigDecimal

    attr_reader :amountOwe, :amountPaid, :user
    attr_writer :amountOwe, :amountPaid, :user

    # amountPaid = the amount the user put into a shared bill
    # amountOwe = the amount of the shared bill the user is responsible for 
    # If I put in $20 for a meal split evenly between me and another person:
    # amountPaid = 20
    # amountOwe = 10
    def initialize(user, amountPaid, amountOwe)
        @user = user
        @amountPaid = BigDecimal.new(amountPaid.to_s)
        @amountOwe = BigDecimal.new(amountOwe.to_s)
    end

    def to_s
        "CGParticipantPayTriple(#{@user}, paid=#{@amountPaid.to_s("F")}, owe=#{@amountOwe.to_s("F")})"
    end

    def CGParticipantPayTriple.validate(triples)
        totalOwed = BigDecimal("0")
        totalPaid = BigDecimal("0")
        triples.each { |t|
            totalOwed += t.amountOwe
            totalPaid += t.amountPaid
        }
        return totalOwed == totalPaid
    end
end

class BigDecimal
    include XML::Mapping
    text_node :to_s, "to_s"

    def BigDecimal.load_from_xml(xml, options={:mapping=>:_default})
        strValue = ""
        xml.each_element { |s|
            strValue = s.text
            break
        }
        BigDecimal.new(strValue)
    end

    def upToWholeCents
        (self * 100).ceil / 100
    end

    def downToWholeCents
        (self * 100).floor / 100
    end

    def roundToWholeCents
        (self * 100).round / 100
    end
end

class CGBill
    include XML::Mapping

    text_node :comment, "@comment"

    object_node :date, "date",
        :unmarshaller=>proc{|xml|
        timeValue = 0
        xml.each_element {|xpath|
            timeValue = xpath.text.to_i
            break
        }
        Time.at(timeValue)
    },
        :marshaller=>proc{|xml,value|
        e = xml.elements.add; e.name = "time"; e.text = value.to_i
    } 

    text_node :uuid, "@uuid"
    array_node :participantPayTriples, "participantPayTriples", "CGParticipantPayTriple", :class=>CGParticipantPayTriple, :default_value=>[]

    attr_reader :participantPayTriples

    def initialize(comment, date, participantPayTriples)
        @comment = comment
        @date = date
        @uuid = `uuidgen`.strip
        @participantPayTriples = participantPayTriples

        valid = CGParticipantPayTriple.validate(participantPayTriples)
        puts "Uh oh, this bill's triples don't add up" unless valid

        puts self.save_to_xml
    end

    # We'll be splitting bills based on percentages and whatnot
    # At the end of the day we need to round fractional cents to get the desired total
    def CGBill.roundAmounts(amounts, desiredTotal)
        # Make sure our input is in terms of whole cents
        desiredTotal = desiredTotal.roundToWholeCents # force our input to be valid
        newAmounts = []
        currentSum = BigDecimal("0")
        amounts.each { |x|
            x = x.downToWholeCents
            newAmounts << x
            currentSum += x
        }
        amounts = newAmounts

        needToDistribute = desiredTotal - currentSum
        raise "There's a problem here! Desired #{desiredTotal.to_s("F")} is less than current sum #{currentSum.to_s("F")}!" unless needToDistribute >= 0
        
        index = 0
        count = amounts.count
        oneCent = BigDecimal.new("0.01")
        while (needToDistribute > 0)
            backwardIndex = count - index - 1 # go backwards, the person who paid shouldn't have to pay the extra cent
            amounts[backwardIndex] = amounts[backwardIndex] + oneCent

            needToDistribute -= oneCent
            index = (index + 1) % count
        end 

        testSum = BigDecimal.new("0")
        amounts.each { |x|
            testSum += x
        }
        raise "There's a problem here! Sum didn't come out to be total  (#{testSum.to_s("F")} != #{desiredTotal.to_s("F")})" unless testSum == desiredTotal

        return amounts
    end

    # total can be BigDecimal or string
    def CGBill.newEvenlySplitBill(comment, users, payingUser, total)
        total = BigDecimal.new(total.to_s)

        first = true
        count = users.count

        triples = []

        amounts = []
        users.each { |u|
            amounts << total / count
        }
        amounts = self.roundAmounts(amounts, total)
       
        index = 0
        users.each { |u|
            amountPaid = (u == payingUser ? total : BigDecimal("0"))
            triples << CGParticipantPayTriple.new(u, amountPaid, amounts[index]) 
            index += 1
        }

        CGBill.new(comment, Time.now, triples)
    end

    def to_s
        "CGBill(#{@comment}, #{@date}, #{@uuid}, paytriples:\n#{@participantPayTriples.join("\n")}\n)"
    end

    def hash
        @uuid.tr("-", '').hex
    end

    def eql?(other)
        return @uuid == other.uuid
    end

end
