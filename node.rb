# Thomas Cornelius
# Shyam Patel
# CMSC417 Project 3
# Part 1 submission

# --- global variables
$ip_address = "127.0.0.1"		#how do we find this out? (address of self)
$ttl = 0
$packet_size = 256
$costs_path = "~/costs.csv"
$dump_path = "table.dump"
$dump_interval = 30
$port = 9999
$round_delay = 10
$costs_delay = 10
$round_time = Time.now
$costs_time = Time.now
$dump_time = Time.now
$version = 0

$circuits = {}

#used to map ip addresses to hostnames
$hostnames = {}

#initializes global vars from config file, initializes network graph,
#propagates hashmap of ip addresses to hostnames,
#creates graphnode of self and inserts into graph.
def init()
	puts "initializing global variables"
	lines = IO.readlines("global.cfg")
	lines.each{ |l|
		elements = l.split("=") #splitting by =
		if elements[0].eql? "packet_size"
			$packet_size = elements[1].to_i
		end
		
		if elements[0].eql? "costs_path"
			$costs_path = elements[1]
		end

		if elements[0].eql? "update_interval"
			$round_delay = elements[1].to_i
		end

		if elements[0].eql? "dump_path"
			$dump_path = elements[1]
		end

		if elements[0].eql? "dump_interval"
			$dump_interval = elements[1].to_i
		end
	}
	
    #---propagating ip to hostname hashmap
    lines = IO.readlines("nodes-to-addrs.txt")
    lines.each{ |l|
        elements = l.split(" ")
        #puts elements[0],elements[1]
        $hostnames[elements[1]] = elements[0] # "'10.0.0.20' = 'n1'"
    }

	#---initialize graph
	#$graph = Graph.new

	#---insert self into graph
	#me = Graphnode.new
	#$graph.insert(me)

end

#runs periodically. updates direct neighbor costs by reading in costs file.
def update_costs()
	puts "updating costs"
	lines = IO.readlines("~/costs.csv")
	lines.each{ |l|
		elements = l.split(",")	#splitting by commas

		if elements[0].eql? "#{$ip_address}"	#if entry is relevant to us
			puts l
			#check if the edge exists in the graph. if not, make a new
			#graphnode and insert into the graph. otherwise update edge
			#with new cost
		end
	}
end

#runs periodically. floods network with advertisement packets.
def broadcast()
	puts "broadcasting packets (TODO)"
	#construct advertisement packet message
	#message = "#{$ip_address},#{graphnode.neighbors},#{$port},#{$version}"
	$version = $version + 1

	#access hashmap of neighbors through graphnode (self). for each edge,
	#send an advertisement packet to them.

	#graphnode.neighbors.each{ |n| 
		#send packet
	#}
end

#runs periodically. allows packets to propagate through network.
def receive()
	puts "receiving and forwarding packets (TODO)"
	#receive packets. forward each packet to all neighbors except sender.
	#for each unique packet, make a graphnode and add to global list.
end

#runs periodically. updates network graph with new information.
def update_graph()
	puts "updating graph (TODO)"
	#create new graph. for each graphnode in global list, insert into graph.
	#generate new forwarding table based on updated network topology.
end

#runs periodically. dumps routing table to file for grading purposes.
def dump_table()
	puts "dumping routing table (TODO)"
end

# --- perform initialization tasks ---

#-> call update_costs() for the first time, propagate neighbor array
#-> identify hostname of self

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

    #check if time to dump routing table
    if curr_time - $dump_time >= $dump_interval
        dump_table()
        $dump_time = curr_time
    end


	#--- check for user input? ---

end


