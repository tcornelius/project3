# Thomas Cornelius
# Shyam Patel
# CMSC417 Project 3
# Part 1 submission

# --- global variables
$ttl = 0
$port = 9999
$round_delay = 10
$costs_delay = 10
$round_time = Time.now
$costs_time = Time.now

$circuits = {}

$temp_neighbors = {}	#used until graph class complete

#initializes global vars from config file, initializes network graph,
#creates graphnode of self and inserts into graph.
def init()
	puts "initializing global variables"
end

#runs periodically. updates neighbor costs by reading in costs file.
def update_costs()
	puts "updating costs"
end

#runs periodically. floods network with advertisement packets.
def broadcast()
	puts "broadcasting packets"
end

#runs periodically. allows packets to propagate through network.
def receive()
	puts "receiving and forwarding packets"
end

#runs periodically. updates network graph with new information.
def update_graph()
	puts "updating graph"
end


# --- perform initialization tasks ---

#-> call update_costs() for the first time, propagate neighbor array

init()

update_costs()
broadcast()	#broadcasts message to neighbors
receive()	#stores and forwards received messages
update_graph()	#updates graph with new information

while 1 < 2 do	#infinite server loop

	curr_time = Time.now

	#check if time to update neighbor costs
	if curr_time - $costs_time >= $costs_delay
		update_costs()
		$costs_time = curr_time
	end

	#check if time to broadcast packets
	if curr_time - $round_time >= $round_delay
		broadcast()
		receive()
		update_graph()
		$round_time = curr_time
	end

	#--- check for user input? ---

end


