#!/usr/bin/ruby
#

class CGOweChart
    def initialize
        # @oweTables[user1][user2] = amount user1 (owes | is owed by) user2
        # if the value is negative, user1 owes user2
        # if the value is positive, user2 owes user1
        @oweTables = Hash.new
    end
    
    def forUser(user)
        return @oweTables[user]
    end

    # Deterministically choose who we owe so results don't differ across multiple runs
    def addBill(bill)
        triples = bill.participantPayTriples.sort { |a,b|
            a.user.uuid <=> b.user.uuid
        }

        # We need some kind of triples we can modify to do book keeping
        # We need to clone them so they're safe to mess up

        scratchTriples = []
        
        triples.each { |triple|
            scratchTriples << CGParticipantPayTriple.new(triple.user, triple.amountPaid, triple.amountOwe)
        }

        triples = scratchTriples

        # Construct an oweTable for each person - can't use a default constructor since we need unique hash instances
        oweTables = Hash.new
        triples.each { |t1|
            oweTables[t1.user] = Hash.new(BigDecimal.new("0"))
        }
        # oweTables[user1][user2] = N
        # if (N > 0) user2 owes user1 N dollars
        # if (N < 0) user1 owes user2 N dollars

        # Normalize all of the triples so that one of amountOwe and amountPaid is 0
        triples.each { |triple|
            if (triple.amountOwe > triple.amountPaid)
                triple.amountOwe -= triple.amountPaid
                triple.amountPaid = BigDecimal.new("0")
            elsif (triple.amountPaid > triple.amountOwe)
                triple.amountPaid -= triple.amountOwe
                triple.amountOwe = BigDecimal.new("0")
            end
        }

        # Move money out of the scratchTriples and into the oweTable
        triples.each { |user1Triple| # user1's triple
            paidOut = user1Triple.amountPaid - user1Triple.amountOwe

            if (paidOut < 0)
                # If paidOut < 0, we need to figure out who we owe
                triples.each { |user2Triple|
                    next if (user1Triple == user2Triple)
                    theyPaidOut = user2Triple.amountPaid - user2Triple.amountOwe
                    if (theyPaidOut > 0)
                        if (theyPaidOut + paidOut >= 0) # we owe them entirely 
                            oweTables[user1Triple.user][user2Triple.user] += paidOut
                            user1Triple.amountOwe += paidOut # should be 0 now
                            raise "Debts should be paid! Instead: #{user1Triple.amountOwe}" unless user1Triple.amountOwe == BigDecimal.new("0")

                            oweTables[user2Triple.user][user1Triple.user] -= paidOut # Don't forget that paidOut < 0
                            user2Triple.amountPaid += paidOut # This portion of our payment has been claimed

                            break
                        else
                            oweTables[user1Triple.user][user2Triple.user] -= theyPaidOut # we consume the entire amount they paid
                            user1Triple.amountOwe -= theyPaidOut

                            oweTables[user2Triple.user][user1Triple.user] += theyPaidOut # we owe user2 theyPaidOut
                            user2Triple.amountPaid -= theyPaidOut 
                            paidOut += theyPaidOut # and we still owe more

                            raise "paidOut mismatch paidOut:#{paidOut} != triple: #{user1Triple}" unless paidOut == (user1Triple.amountPaid - user1Triple.amountOwe)
                        end
                    end
                }
            elsif (paidOut > 0)
                # If paidOut > 0, we need to figure out who owes us
                triples.each { |user2Triple|
                    next if (user1Triple == user2Triple)
                    theyPaidOut = user2Triple.amountPaid - user2Triple.amountOwe
                    if (theyPaidOut < 0)
                        paidOutSum = theyPaidOut + paidOut
                        if (paidOutSum >= 0) # they owe us entirely
                            oweTables[user1Triple.user][user2Triple.user] += -theyPaidOut
                            user1Triple.amountPaid += theyPaidOut # This portion of our payment has been claimed

                            oweTables[user2Triple.user][user1Triple.user] += theyPaidOut # Don't forget that theyPaidOut < 0
                            user2Triple.amountOwe += theyPaidOut # should be 0 now  
                            raise "(user2)Debts should be paid! Instead: #{user2Triple.amountOwe}" unless user2Triple.amountOwe == BigDecimal.new("0")

                            paidOut += theyPaidOut # and we still have more that needs to be claimed

                            raise "paidOut mismatch paidOut:#{paidOut} != triple: #{user1Triple}" unless paidOut == (user1Triple.amountPaid - user1Triple.amountOwe)
                            raise "user1 should still have unclaimed payment!" unless (paidOut > 0 || (paidOutSum == 0))
                        else # We can only partially cover their debt
                            oweTables[user1Triple.user][user2Triple.user] += paidOut # we consume the entire amount we paid on their debt
                            user1Triple.amountPaid -= paidOut # This portion of our payment has been claimed
                            # we have no more to pay out
                            raise "User1's payment should have been fully consumed. Instead: #{user1Triple.amountPaid}" unless user1Triple.amountPaid == BigDecimal.new("0")

                            oweTables[user2Triple.user][user1Triple.user] += -paidOut # They owe us the entire amount we paid
                            user2Triple.amountOwe += paidOut 
                            
                            break
                        end
                    end
                }
            end
        }


        # Actually, we want to combine @oweTables and oweTables
        # Sum these new results into the original table
        oweTables.each { |user1, table|
            if (@oweTables[user1].nil?)
                @oweTables[user1] = Hash.new
            end
            oweTables[user1].each { |user2, amount|
                if (@oweTables[user1][user2].nil?)
                    @oweTables[user1][user2] = BigDecimal.new("0")
                end
                @oweTables[user1][user2] += amount
            }
        }
        #puts "oweTable: #{@oweTables.inspect}"
    end

end


