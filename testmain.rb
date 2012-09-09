#!/usr/bin/ruby
#

require 'CGUser'
require 'CGUserGroup'
require 'CGBill'
require 'CGPersistedHistory'
require 'CGOweChart'

# Create a few users
u1 = CGUser.new("Danny", "redactedd@gmail.com")
u2 = CGUser.new("Walter", "redactedw@gmail.com")
u3 = CGUser.new("Henry", "redactedh@me.com")
puts "u1: #{u1.save_to_xml.class}"

u4 = CGUser.load_from_xml(u1.save_to_xml)
puts "U4: #{u4}"

puts "Two new users:\n#{u1}\n#{u2}"

bill1 = CGBill.newEvenlySplitBill("test bill", [u1, u2, u3], u1, "20")
puts "Bill: #{bill1}"

bill2 = CGBill.newEvenlySplitBill("test bill2", [u1, u2], u1, "21.01")
puts "Bill: #{bill2}"

bill3 = CGBill.newEvenlySplitBill("test bill3", [u1, u2, u3], u1, "3.01")
puts "Bill: #{bill3}"

puts "======="
history = CGHistory.new
history.addUser(u1)
history.addUser(u2)
history.addUser(u3)

puts "======="
history.addBill(bill1)
history.addBill(bill2)
history.addBill(bill3)
puts history
puts "======="

filename = "test.out"
history.writeToFile(filename)

history2 = CGHistory.load_from_file(filename)
puts "======="
puts "History2: #{history2}"


u2OweChart = CGOweChart.new
u2OweChart.addBill(bill3)
puts "u2 owe chart: #{u2OweChart.forUser(u2).inspect}"
historyU2 = CGHistory.new
historyU2.addBill(bill3)
puts "U2 owe chart: #{historyU2.oweChartForUser(u2).inspect}"

puts "u1 owe chart:"
u1OweChart = CGOweChart.new
u1OweChart.addBill(bill3)
u1OweChart.addBill(bill2)
puts "u1 owe chart: #{u1OweChart.forUser(u1).inspect}"
historyU1 = CGHistory.new
historyU1.addBill(bill3)
historyU1.addBill(bill2)
puts "U1 owe chart: #{historyU1.oweChartForUser(u1).inspect}"

puts "u3 owe chart:"
u3OweChart = CGOweChart.new
u3OweChart.addBill(bill3)
u3OweChart.addBill(bill2)
puts "u3 owe chart: #{u3OweChart.forUser(u3).inspect}"
historyU3 = CGHistory.new
historyU3.addBill(bill3)
historyU3.addBill(bill2)
puts "U3 owe chart: #{historyU3.oweChartForUser(u3).inspect}"

puts "======="

def oweString(oweChart)
    message = ""
    comma = ""
    if (oweChart.count == 0)
        message << "You are even!"
    end
    oweChart.each { |otherCGUser,oweAmount|
        if (oweAmount > 0) # otherCGUser owes cgUser
            message << "#{comma}#{otherCGUser.name} owes you #{oweAmount.moneyString}"
        else
            message << "#{comma}You owe #{otherCGUser.name} #{(-oweAmount).moneyString}"
        end
        comma = "\n"
    }
    return message
end



history3 = CGHistory.new

billA = CGBill.newEvenlySplitBill("test bill", [u1, u2], u1, "200")
billB = CGBill.newEvenlySplitBill("test bill", [u3, u2], u2, "200")
history3.addUser(u1)
history3.addUser(u2)
history3.addUser(u3)
history3.addBill(billA)
history3.addBill(billB)
puts "old charts:\n"
puts "u1(#{u1.name}) owe chart: #{oweString(history3.oweChartForUser(u1))}\n========\n"
puts "u2(#{u2.name}) owe chart: #{oweString(history3.oweChartForUser(u2))}\n========\n"
puts "u3(#{u3.name}) owe chart: #{oweString(history3.oweChartForUser(u3))}\n========\n"
puts "new charts:\n"
group = CGUserGroup.new("testgroup", [u1,u2,u3])
shuffledOweChart = history3.shuffleDebtsForGroup(group, true)
puts "u1(#{u1.name}) owe chart: #{oweString(shuffledOweChart.forUser(u1))}\n========\n"
puts "u2(#{u2.name}) owe chart: #{oweString(shuffledOweChart.forUser(u2))}\n========\n"
puts "u3(#{u3.name}) owe chart: #{oweString(shuffledOweChart.forUser(u3))}\n========\n"
