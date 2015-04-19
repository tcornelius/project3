# Thomas Cornelius
# Shyam Patel
# CMSC417 Project 3
# Part 1 submission

#!!! Test marker

require 'socket'
require "/home/core/sandbox/project3/graph"

# --- global variables
$port = 9998
$ttl = 0
$packet_size = 256
$costs_path = "/home/core/costs.csv"
$dump_path = "table.dump"
$dump_interval = 10
$round_delay = 5
$costs_delay = 60
$round_time = Time.now
$costs_time = Time.now
$dump_time = Time.now
$version = 0
$me_node = nil

$circuits = {}

#used to map ip addresses to hostnames
$my_hostname = ""
$hostnames = {}
$my_interfaces = [] #array of this host's interfaces

$my_links = {}      #hashmap of neighbor hostnames to interfaces: e.g. for n1: 
                    #my_links["n2"] = "10.0.1.21"
                    #keyset is list of neighbor hostnames

$costs = {}         #hashmap of neighbor hostnames to their costs. updated
                    #periodically by update_costs()

$routing_table = {} #hashmap of destinations to next nodes

$network = nil

#initializes global vars from config file, initializes network graph,
#propagates hashmap of ip addresses to hostnames, identifies self
#creates graphnode of self and inserts into graph.
def init()
	puts "initializing global variables"
	lines = IO.readlines("/home/core/global.cfg")
	lines.each{ |l|
		elements = l.split("=") #splitting by =
		if elements[0] == "packet_size"
			$packet_size = elements[1].to_i
		end
		
		if elements[0] == "costs_path"
			$costs_path = elements[1]
		end

		if elements[0] == "update_interval"
			$round_delay = elements[1].to_i
		end

		if elements[0] == "dump_path"
			$dump_path = elements[1]
		end

		if elements[0] == "dump_interval"
			$dump_interval = elements[1].to_i
		end
	}
	
    #identify self
    $my_hostname = `hostname`   #executes unix command 'hostname'
    $my_hostname = $my_hostname.strip()
    #!!!
    #$my_hostname = "n1"         #test case
    #puts $my_hostname

    #---propagating ip to hostname hashmap
    lines = IO.readlines("/home/core/nodes-to-addrs.txt")
    lines.each{ |l|
        elements = l.split(" ")
        #puts elements[0],elements[1]
        $hostnames[elements[1]] = elements[0] # "'10.0.0.20' = 'n1'"
        
        
        if elements[0] === $my_hostname
            #puts "adding"
            $my_interfaces.push(elements[1]) #keep track of our interfaces
        end
    }
  
    #puts $my_interfaces
    #figure out neighbors + their interfaces. store key val pairs in $my_links

    lines = IO.readlines("/home/core/addrs-to-links.txt")
    lines.each{ |l|
        elements = l.split(" ")
        
        if $my_interfaces.include? elements[0]
            $my_links[$hostnames[elements[1]]] = elements[1]
        end

        if $my_interfaces.include? elements[1]
            $my_links[$hostnames[elements[0]]] = elements[0]
        end
    }

    #puts $my_links.keys
    
    # populating $costs
    

	#---initialize graph
	$network = Graph.new
	#---insert self into graph
	me = Graph_Node.new(@hostname,$version)
    $me_node = me
    
    #puts $my_links.keys
    $my_links.keys.each{ |host|
        puts "adding neighbor to graph"
        node = Graph_Node.new(host, $version)
        temp = {}
        $network.add_node(node, temp)
    }
    $network.add_node(me, $costs)

    cost_lines = IO.readlines("/home/core/costs.csv")
    
    #!!!
    #lines = IO.readlines("costs.csv")   #for testing purposes

    #neighbors_mentioned = []
    #---
	cost_lines.each{ |l|
		elements = l.split(",")	#splitting by commas
        
		if $my_interfaces.include? elements[0] #if entry is relevant to us
			
            temp_node = nil
            neighbor = $hostnames[elements[1]]
            $network.vertices.keys.each{ |v|
                if v.hostname === neighbor
                    temp_node = v
                end
            }

            cost = elements[2].to_i
			$costs[neighbor] = cost
            #puts temp_node
            $network.vertices[me][temp_node] = cost
            #add other way?

            #neighbors_mentioned.push(neighbor)
		end

	}
    #---
	

    #puts $network.vertices.keys
    #exit()
    #---run djikstras, generate early routing table

end

#runs periodically. updates direct neighbor costs by reading in costs file.
def update_costs()
	puts "updating costs from file"
	lines = IO.readlines("/home/core/costs.csv")
    #!!!
    #lines = IO.readlines("costs.csv")   #for testing purposes

    #neighbors_mentioned = []

	lines.each{ |l|
        #puts l
		elements = l.split(",")	#splitting by commas

		if $my_interfaces.include? elements[0] #if entry is relevant to us
			temp_node = nil
            neighbor = $hostnames[elements[1]]
            $network.vertices.keys.each{ |v|
                if v.hostname === neighbor
                    temp_node = v
                end
            }

            neighbor = $hostnames[elements[1]]
            cost = elements[2].to_i
			$costs[neighbor] = cost

            $network.vertices[$me_node][temp_node] = cost

            #neighbors_mentioned.push(neighbor)
		end

	}

    #neighbors_mentioned.each{ |n|
     #   if not($my_links.keys.include? n)
            #add to everything
      #  end

    #}

    #$my_links.keys.each{ |n|
     #   if not(neighbors_mentioned.include? n)
            #remove from everything
      #      $my_links
       # end

    #}



    #puts $costs.inspect
    #---update graph with new information
    
end

#runs periodically - updates routing table
def update_routing_table()
    puts "Updating routing table"
    # run dijsktra from us to every other node in the graph $network
    $routing_table[$my_hostname] = $my_hostname
    $network.vertices.each {|host, edges|
        if(host.hostname != $my_hostname)
            
            # running dijkstra's on every node in the graph from the current node and adding the 1st neighbor to the routing table. 
            next_neighbor = $network.dijsktra($my_hostname, host).last
            if(next_neighbor != nil)
                routing_table[host] = next_neighbor
            end
        end
    }


end

#runs periodically. floods network with advertisement packets.
def broadcast()
	puts "broadcasting packets"
	#construct advertisement packet message
    puts "#{$costs.inspect}"
	message = "FLOOD#{$my_hostname},#{$costs.inspect},#{$version}"
    #puts message
    #broadcast message to all neighbors
    #puts "hi "+"#{$my_links}"
    $my_links.keys.each{ |host|
        
        begin
            puts "sending packet to #{host}: #{$my_links[host]}"
            sock = TCPSocket.new($my_links[host], $port)    #open socket
            sock.write(message)                             #sending message
            sock.close
        rescue Errno::ECONNREFUSED
            puts "connection refused"
        end
    }

end

#function to handle external advertisement packets
def flood(message)
	puts "processing advertisement packet"
    packet = message.split(",")
    sender = packet[0]

    #receive a packet. forward it to all neighbors except sender.

    $my_links.keys.each{ |host|
        
        if not(host == sender)    
            sock = TCPSocket.new($my_links[host], $port)    #open socket
            sock.write(message)                             #sending message
            sock.close
        end

    }
    
    #process message.
    /FLOOD(.*),\{(.*)\},(.*)/.match(message)
    sender = $1
    links = $2
    version = $3

    links = links[1..links.length-1] #strip {}
    link_list = links.split(',')
    link_list.each{ |link|
        elements = link.split("=>")
        neighbor = elements[0][1..elements[0].length-1] #strip quotes
        cost = elements[1].to_i

        if not($network.vertices.keys.include? neighbor)
            #if neighbor is not known
            node = Graph_Node.new(neighbor,$version)
            $network.add_node(node, {})
        end

        #make sure this doesn't have quotes around it
        $network.vertices[sender][neighbor] = cost
    }
    
	update_routing_table()
end


#runs periodically. dumps routing table to file for grading purposes.
def dump_table()
	puts $routing_table.inspect
    #will complete after routing table functionality is implemented
end

# --- perform initialization tasks ---

#-> call update_costs() for the first time, propagate neighbor array
#-> identify hostname of self

init()

update_costs()

serv_socket = TCPServer.new('',$port)
serv_socket.listen(15)   #backlog of 15

#!!!
sleep(3)       #make sure all other nodes are listening?
broadcast()     #first broadcast

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
		$round_time = curr_time
	end

    #check if time to dump routing table
    if curr_time - $dump_time >= $dump_interval
        dump_table()
        $dump_time = curr_time
    end


    #---handle received messages---
    begin
        conn = serv_socket.accept_nonblock  #accept a connection if any in queue
        message = conn.recv($packet_size)
        puts message
        conn.close()
        
        #if it's an advertisement
        if message[0..5] == "FLOOD"
            flood(message)
        end

        #otherwise...?
    

    rescue Errno::EAGAIN,Errno::EWOULDBLOCK
        #nothing in queue!
    end

	#--- check for user input? (i.e. message sending?) ---

end


