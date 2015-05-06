# Thomas Cornelius
# Shyam Patel
# CMSC417 Project 3
# Part 2 submission

#!!! Test marker

require 'socket'
require 'openssl'
require "/home/core/graph"

# --- global variables
$port = 9998
$ttl = 0
$packet_size = 256
$costs_path = "/home/core/costs.csv"
$dump_path = "table.dump"
$dump_interval = 10
$round_delay = 0.5
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

$received_broadcasts = [] #array of received advertisements

$network = nil

$public_keys = {}   #hash of public keys
$private_key = ''   #this node's private key

class Circuit
    attr_accessor   :tag,:next_node,:prev_node,:data,:src,:dst
    
    def initialize(tag,next_node,prev_node)
        @tag = tag
        @next_node = next_node
        @prev_node = prev_node
        @data = ""  #empty string to hold data

        /(.*)->(.*)/.match(tag)
        @src = $1
        @dst = $2
    end
end

#initializes global vars from config file, initializes network graph,
#propagates hashmap of ip addresses to hostnames, identifies self
#creates graphnode of self and inserts into graph.
def init()
	#puts "initializing global variables"
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

    #read in public keys, retrieve private key
    generate_keys() 
     
    #puts $my_links.keys
    
    # populating $costs
    

	#---initialize graph
	$network = Graph.new()
	#---insert self into graph
    
	me = Graph_Node.new($my_hostname,$version)
    $me_node = me
    
    #puts $my_links.keys
    $my_links.keys.each{ |host|
        #puts "adding neighbor to graph"
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
        temp_node = nil
		if $my_interfaces.include? elements[0] #if entry is relevant to us
			#puts $costs.inspect
            
            neighbor = $hostnames[elements[1]]
            #puts neighbor.class

            $network.vertices.keys.each{ |v|
                if v.hostname === neighbor
                    temp_node = v
                end
            }
            
            cost = elements[2].to_i
            #puts "keys "+"#{$costs.keys}"

            if not(neighbor.class == String)
                next
            end

            #puts neighbor
            
			$costs[neighbor] = cost
            #puts $costs.inspect
            #puts temp_node
            $network.vertices.keys.each{ |k|
                #puts "#{k.hostname}: #{$network.vertices[k].inspect}"
            }
            if not(temp_node == nil)
                $network.vertices[me][temp_node] = cost
                $network.vertices[temp_node][me] = cost
            end
            #puts
                       
            #add other way?
            #puts $costs.inspect
            #neighbors_mentioned.push(neighbor)
            #puts i
            
		end

	}
    
    $network.vertices.keys.each{ |k|
        $network.vertices[k].keys.each{ |k2|
            if k2.class == String
                $network.vertices[k].delete(k2)
            end
        }
    }
    #---
	$network.vertices.keys.each{ |k|
        #puts "#{k.hostname}: #{$network.vertices[k].inspect}"
    } 

    #puts $network.vertices.keys
    #exit()
    #---run djikstras, generate early routing table

end

#loads keys from file
def generate_keys()
    # loads the hashed dump files
    if File.exists?('/home/core/public.keys') 
        #puts "loading public keys"
        $public_keys = Marshal.load(File.read('/home/core/public.keys'))
    end 
    if File.exists?('/home/core/private.keys')
        #puts "loading private key" 
        private_keys = Marshal.load(File.read('/home/core/private.keys'))
    end 

    #puts private_keys.inspect
    $private_key = private_keys[$my_hostname]
    #puts $public_keys["n2"]

    if($public_keys.size < 1 or private_keys.size < 1 or $public_keys.size != private_keys.size)
        puts "Invalid key dump files."
    end
end

#runs periodically. updates direct neighbor costs by reading in costs file.
def update_costs()
	#puts "updating costs from file"
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

            #puts $network.vertices.keys.inspect
            $network.vertices.keys.each{ |v|
                if v == nil
                    #puts $network.vertices.keys.inspect
                    next
                end

                if v.hostname === neighbor
                    temp_node = v
                end
            }

            cost = elements[2].to_i
			$costs[neighbor] = cost

            if $network.vertices[temp_node] == nil
                $network.vertices[temp_node] = {}    
            end
            
            if not(temp_node == nil)
                $network.vertices[$me_node][temp_node] = cost
                $network.vertices[temp_node][$me_node] = cost
            end
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
def update_routing_table(graph, me)
    #puts "Updating routing table"
    # run dijsktra from us to every other node in the graph $network
    
    $routing_table[$my_hostname] = $my_hostname
    graph.vertices.keys.each {|host|
        #puts "#{host.hostname}: #{graph.vertices[host].inspect}"
        #puts
        if(host.hostname != $my_hostname)
            
            # running dijkstra's on every node in the graph from the current node and adding the 1st neighbor to the routing table.

            
            next_neighbor = graph.dijkstra(me, host)
            if(next_neighbor.class == Array)
                $routing_table[host.hostname] = next_neighbor.last
            else
                $routing_table[host.hostname] = -1
            end
        end
    }


end

#runs periodically. floods network with advertisement packets.
def broadcast()
	#puts "broadcasting packets"
	#construct advertisement packet message
    #puts "#{$costs.inspect}"
    hash = {}
    $costs.keys.each{ |k|
        if k.class == String
            hash[k] = $costs[k] #weed out mystical spooky keys
        end
    }
	message = "FLOOD#{$my_hostname},#{hash.inspect},#{$version}"
    #puts message
    #broadcast message to all neighbors
    #puts "hi "+"#{$my_links}"
    $my_links.keys.each{ |host|
        if($my_links[host] == nil)
            next
        end

        begin
            #puts "sending packet to #{host}: #{$my_links[host]}"
            sock = TCPSocket.new($my_links[host], $port)    #open socket
            sock.write(message)                             #sending message
            sock.close
        rescue Errno::ECONNREFUSED
            #puts "connection refused"
            
        end
    }

end

#function to handle external advertisement packets
def flood(message)
	#puts "processing advertisement packet"
    if($received_broadcasts.include?(message))
        num = rand(11)
        if (num > 5)    #probabilistic flooding to reduce network traffic
            return
        end
    else
        $received_broadcasts.push(message)
    end

    

    packet = message.split(",")
    sender = packet[0]

    #receive a packet. forward it to all neighbors except sender.
    #ignore packets from self
    #process message.
    /FLOOD(.*),\{(.*)\},(.*)/.match(message)
    sender = $1
    #puts sender
    if sender === $my_hostname
        return
    end

    links = $2
    version = $3

    links = links.strip
    
    link_list = links.split(', ')
    
    link_list.each{ |link|
        elements = link.split("=>")
        neighbor = elements[0][1..elements[0].length-2] #strip quotes
        
        cost = elements[1].to_i
        node = nil
        node2 = nil

        $network.vertices.keys.each{ |v|
            if v == nil
                next
            end

            if v.hostname === neighbor
                node = v
            end
        }

        if node == nil
            #if neighbor is not known
            node = Graph_Node.new(neighbor,$version)
            $network.add_node(node, {})
        end

        #make sure this doesn't have quotes around it
        $network.vertices.keys.each{ |v|
            if v.hostname === sender
                node2 = v
            end
        }

        if node2 == nil
            node2 = Graph_Node.new(sender,$version)
            $network.add_node(node2, {})
        end
        #puts node2
        #puts $network.vertices[node2]
        if $network.vertices[node] == nil
            $network.vertices[node] = {}    
        end

        if $network.vertices[node2] == nil
            $network.vertices[node2] = {}    
        end

        if (not(node2 == nil) and not(node == nil))
            $network.vertices[node2][node] = cost
            $network.vertices[node][node2] = cost
        end
    }

    $my_links.keys.each{ |host|
        
        if not(host == sender)    
            begin
                sock = TCPSocket.new($my_links[host], $port)    #open socket
                sock.write(message)                             #sending message
                sock.close
            rescue Errno::ECONNREFUSED
            end
        end

    }
    
    
    
	update_routing_table($network, $me_node)
end


#runs periodically. dumps routing table to file for grading purposes.
def dump_table()
    #puts "======= Routing Table ======="
	#puts $routing_table.inspect
    File.open($dump_path, 'w'){ |file|

        file.write("====Routing Table:#{$my_hostname}====\n")
        file.write("DEST\t\tNEXT\n")
        $routing_table.keys.each{ |k|
            moop = $routing_table[k]
            
            if not($routing_table[k].class == String)
                moop = $routing_table[k].hostname
            end

            file.write("#{k}\t\t#{moop}\n")
        }
    }
    
    #will complete after routing table functionality is implemented
end

#removes a node from the graph and entry from routing table, then updates
def remove_node(dst)
    #puts "removing node and updating table"
    if (dst == $my_hostname)
        puts "Node removal error"
        exit()
    end
    n = $routing_table[dst]
    $routing_table.delete(n.hostname)
    
    $network.vertices.delete(n)
    #update routing table
    update_routing_table($network, $me_node)
end

#establishes a virtual circuit along the path to hostname
def establish_circuit(hostname)
    node = $routing_table[hostname]
    if node == nil or node == $my_hostname
        puts "unable to route to host"
        return
    end
    
    nextnode = node.hostname
    message = "CIRCUIT#{$my_hostname}->#{hostname}"
    
    #---propagate fields of struct & add to list
    c = Circuit.new("#{$my_hostname}->#{hostname}", nextnode, nil)
    #puts "establishing circuit: #{$my_hostname}->#{hostname}"
    $circuits["#{$my_hostname}->#{hostname}"] = c

    #--- 

    begin
        #puts "sending circuit packet to #{hostname}: #{$my_links[hostname]}"
        sock = TCPSocket.new($my_links[nextnode], $port)    #open socket
        sock.write(message)                             #sending message
        sock.close
    rescue Errno::ECONNREFUSED
        puts "connection refused"
        remove_node(hostname)
    end
    
    sleep(1)    #wait for circuit setup

end

def handle_circuit(message)
    #puts("establishing circuit on this node")
    /CIRCUIT(.*)->(.*)/.match(message)
    src = $1
    dst = $2
    #puts "src=#{src}, dst=#{dst}"
    if dst === $my_hostname
        c = Circuit.new("#{$1}->#{$2}", nil, $routing_table[src].hostname)
        $circuits["#{$1}->#{$2}"] = c
        return  
    end

    node = $routing_table[dst]
    #puts $routing_table

    #---propagate fields of struct & add to list
    c = Circuit.new("#{$1}->#{$2}", node.hostname, $routing_table[src].hostname)
    $circuits["#{$1}->#{$2}"] = c    

    #---    
    begin
        #puts "sending circuit packet to #{node.hostname}: #{$my_links[node.hostname]}"
        sock = TCPSocket.new($my_links[node.hostname], $port)    #open socket
        sock.write(message)                             #sending message
        sock.close
    rescue Errno::ECONNREFUSED
        #puts "connection refused"
        remove_node(dst)
        handle_circuit(message)
    end
    
end

def start_sendmsg(cmd, msg_socket)
    /SENDMSG ([a-zA-Z0-9]+) (.*)/.match(cmd)
    dst = $1
    data = $2
    
    #puts $private_key
    rsa = OpenSSL::PKey::RSA.new($private_key, $my_hostname)
    #hash data
    sha256 = OpenSSL::Digest::SHA256.new
    digest = sha256.digest(data)

    #sign hash
    sig = rsa.private_encrypt(digest)
    #puts "sig = #{sig}"
    
    check = rsa.public_decrypt(sig)
    
    #puts "check=#{check}"
    #puts "digst=#{digest}"
    #exit()
    #puts "data=#{data}"
    #if(dst == nil)
    #    puts "SENDMSG ERROR: Illegal message"
    #end

    if($routing_table[dst] == nil)
        puts "SENDMSG ERROR: HOST UNREACHABLE"
        return
    end

    establish_circuit(dst)
    sleep(1)

    str = "#{$my_hostname}->#{dst}"
    #puts str
    #puts $circuits.inspect
    circuit = $circuits[str]
    #puts "circuit:"
    #puts circuit.inspect

    nextnode = circuit.next_node

    #craft message
    data_len = data.length
    message = "SENDMSG #{$my_hostname}->#{dst} "
    header_len = message.length #length of header

    index = 0

    begin
        #puts "beginning SENDMSG to #{$my_links[nextnode]}"
        sock = TCPSocket.new($my_links[nextnode], $port-2)
        
        while (index < data_len)
            max_chunk = $packet_size - header_len   #max data per packet
            len = (data_len - index) < max_chunk ? (data_len - index) : max_chunk

            curr_message = message + data[index..(index+len)]
 
            sock.write(curr_message)
            
            index = index + len     #update index
            #puts "data_len=#{data_len}  index=#{index} len=#{len}"
            sleep(1)
        end

        sock.close
        #send end marker
        #---
        #puts "sending end packet"
        sock = TCPSocket.new($my_links[nextnode], $port-2)
        sock.write("END #{$my_hostname}->#{dst} SIG::#{sig}")
        sock.close

    rescue Errno::ECONNREFUSED
        #---
        puts "SENDMSG ERROR: HOST UNREACHABLE"
        return
    end
    #wait for confirmation. timeout?
    start_time = Time.now

    loop{
        begin
            conn = msg_socket.accept_nonblock
            mess = conn.recv($packet_size)
            conn.close()
            ret = handle_sendmsg(mess)
            #puts "ret = #{ret}"
            if ret == "success"
                #puts "successful message transmission"
                break
            end

            if (Time.now - start_time > 5)
                puts "SENDMSG ERROR: HOST UNREACHABLE"
                break
            end

        rescue Errno::EAGAIN,Errno::EWOULDBLOCK
            #nothing in queue!
        end
    }
    
end

def handle_sendmsg(message)
    #puts "handling SENDMSG packet"
    #puts "message=#{message}"
    /([A-Z]+) ([a-zA-Z0-9]+)->([a-zA-Z0-9]+) (.*)/.match(message)
    #arr = message.split(' ')

    arr = message.split(' ')
    #puts arr
    type = arr[0]
    src = ''
    dst = ''
    packet_data = ''
    sig = ''

    #puts "type = #{type}"
    if type == "SENDMSG"
        /([A-Z]+) ([a-zA-Z0-9]+)->([a-zA-Z0-9]+) (.*)/.match(message)
        type = $1
        src = $2
        dst = $3
        packet_data = $4
    end

    if type == "END"
        /(.*) (.*)->(.*) SIG::(.*)/.match(message)
        type = $1
        src = $2
        dst = $3
        sig = message[(3+1+src.length+2+dst.length+1+5)..message.length]
        #puts "sig=#{sig}"
    end

    if type == "CONFIRM"
        /(.*) (.*)->(.*)/.match(message)
        type = $1
        src = $2
        dst = $3

        #puts dst
    end

    
    #puts "type=#{type},src=#{src},dst=#{dst},data=#{packet_data}"
    #fetch circuit struct
    circuit = $circuits["#{src}->#{dst}"]
    #puts $circuits
    #puts circuit.inspect
    
    #puts "dst = #{dst}, my hostname = #{$my_hostname}"
    if(dst == $my_hostname)
        if(type == "END")
            #puts "END of message"
            #print out circuit.data, message received
            rsa = OpenSSL::PKey::RSA.new($public_keys[src])
            verified = false
            #hash data
            sha256 = OpenSSL::Digest::SHA256.new
            digest = sha256.digest(circuit.data)

            #verify signature
            check = rsa.public_decrypt(sig)
            #puts "#{check}  :  #{sig}"
            if (check == digest)
                verified = true
            end

            if (verified)
                puts "Signature verified: #{src}"
                puts "RECEIVED MSG #{src} #{circuit.data}"
            else
                puts "RECEIVED MSG ERROR: #{src} Signature verification failed"
            end
            #send confirmation to src
            begin
                
                nextnode = circuit.prev_node
                confirmation = "CONFIRM #{dst}->#{src}"
                sock = TCPSocket.new($my_links[nextnode], $port-2)
                sock.write(confirmation)
                sock.close
            rescue Errno::ECONNREFUSED
                puts "conn refused (handle_sendmsg)"
                remove_node(dst)
                handle_sendmsg(message)
            end

            #tear down circuit
            $circuits.delete("#{src}->#{dst}")
            return "complete message received"
        end

        if(type == "SENDMSG") 
            #puts "adding to buffer"  
            #add to circuit buffer
            if(packet_data == nil)
                return
            end

            circuit.data = circuit.data + packet_data
            return "added data to buffer"
            #puts "this should never print"
        end

        if(type == "CONFIRM")   #transmission successful
            #puts "CONFIRM message"
            return "success"
        end
    end

    #if we're not the dst

    #puts "FORWARDING MESSAGE"
    #puts message
    if(type == "CONFIRM")   #forward to src, not dst. teardown circuit
        #puts "forwarding confirmation"
        circuit = $circuits["#{dst}->#{src}"]
        nextnode = circuit.prev_node       
        begin
            sock = TCPSocket.new($my_links[nextnode], $port-2)
            sock.write(message)
            sock.close
        rescue Errno::ECONNREFUSED
            #---
            #puts "conn refused (handle_sendmsg)"
            remove_node(src)
            handle_sendmsg(message)
        end

        #tear down circuit at this node
        $circuits.delete("#{dst}->#{src}") #src and dst are switched (going other way)
        
    else                    #forward to dst
        nextnode = circuit.next_node
        begin
            sock = TCPSocket.new($my_links[nextnode], $port-2)
            sock.write(message)
            sock.close
        rescue Errno::ECONNREFUSED
            #---
            #puts "SEND"
            remove_node(dst)
            handle_sendmsg(message)
        end
    end

    return "forwarded"
end

def start_ping(cmd, ping_socket)
    

    /PING (.+) (.+) (.+)/.match(cmd)
    dst = $1
    numpings = $2
    delay = $3

    if(not($routing_table.keys.include? dst))
        puts "PING ERROR: UNKNOWN HOST"
        #puts $routing_table.inspect
        return
    end

    
    #craft ping message
    message = "PING #{$my_hostname}->#{$1}"
    nextnode = $routing_table[dst].hostname
    
    num = numpings.to_i
    #send it forward
    begin
        puts "pinging #{$1}..."
        while(num > 0)
            start_time = Time.now
            #puts "pinging through #{nextnode}"
            sock = TCPSocket.new($my_links[nextnode], $port-1)
            sock.write(message)
            sock.close
            
            #handle ping messages until complete or timeout
            
            loop{
                begin

                    if (Time.now - start_time > 5)
                        puts "PING ERROR: HOST UNREACHABLE"
                        break
                    end

                    conn = ping_socket.accept_nonblock
                    mess = conn.recv($packet_size)
                    #puts "mess=#{mess}"
                    conn.close()
                    ret = handle_ping(mess)
                    if ret == "done"
                        end_time = Time.now
                        puts "Reply from #{dst}: time=#{end_time-start_time}s"
                        break
                    end

                    
                    

                rescue Errno::EAGAIN,Errno::EWOULDBLOCK
                #nothing in queue!
                end
            }

            num = num - 1
            sleep(delay.to_i)
        end
        puts "PING complete."
    rescue Errno::ECONNREFUSED
        #puts "connection refused (start_ping)"
        remove_node(dst)
        start_ping(cmd, ping_socket)
        return
    end
    
end

def handle_ping(message)
    #puts "received ping msg: #{message}"
    /(.*) (.*)->(.*)/.match(message)
    ping = $1
    src = $2
    dst = $3

    if(not($routing_table.keys.include? dst))
        #sleep(4)
        #puts "PING ERROR: HOST UNREACHABLE"
        return
    end

    if(dst == $my_hostname and ping == "PING")
        #send PINGResponse packet back
        retmess = "PINGR #{$3}->#{$2}"
        nextnode = $routing_table[$2]
        begin
            sock = TCPSocket.new($my_links[nextnode], $port-1)
            sock.write(retmess)
            sock.close
        rescue Errno::ECONNREFUSED
            #puts "connection refused - line 794"
            remove_node($2)
            handle_ping(message)
        end
        
        return

    elsif (dst == $my_hostname and ping == "PINGR")
        return "done"
    end

    #craft ping message
    mess = "#{$1} #{$2}->#{$3}"
    nextnode = $routing_table[dst].hostname
    
    #send it forward
    begin
        #puts "forwarding ping packet to #{nextnode} for #{dst}"
        sock = TCPSocket.new($my_links[nextnode], $port-1)
        sock.write(mess)
        sock.close

    rescue Errno::ECONNREFUSED
        #puts "connection refused - line 814"
        #remove node from graph & routing table
        remove_node(dst)
        
        handle_ping(message)
    end
end

def start_traceroute(cmd, tracert_socket)
    #puts "tracing..."

    /TRACEROUTE (.+)/.match(cmd)
    dst = $1

    if(not($routing_table.keys.include? dst))
        puts "TRACEROUTE ERROR: UNKNOWN HOST"
        return
    end

    #craft trace message
    message = "TRACE #{$my_hostname}->#{$1}"
    nextnode = $routing_table[dst].hostname
    #puts "nextnode = #{nextnode}"
    #puts message
    begin
        #send out the traceroute request
        start_time = Time.now
        sock = TCPSocket.new($my_links[nextnode], $port-3)
        sock.write(message)
        sock.close
        puts "tracing..."
        loop{
                begin
                    
                    if (Time.now - start_time > 6)
                        puts "TRACEROUTE ERROR: HOST UNREACHABLE"
                        break
                    end

                    conn = tracert_socket.accept_nonblock
                    mess = conn.recv($packet_size)
                    #puts "mess=#{mess}"
                    conn.close()
                    ret = handle_traceroute(mess)
                    if ret == "trace_complete"
                        end_time = Time.now
                        arr = mess.split(' ')   #data starts at arr[2]
                        i = 2
                        while(i < arr.length)
                            /(.*)=>(.*)/.match(arr[i])
                            #puts mess
                            puts "#{i-1} #{($2.to_f - start_time.to_f)*2}s #{$1}"
                            i = i + 1
                        end
                        puts "Trace complete."
                        break
                    end

                    

                rescue Errno::EAGAIN,Errno::EWOULDBLOCK
                #nothing in queue!
                end
        }
    rescue Errno::ECONNREFUSED
        #---
        #puts "connection refused - start_traceroute"
        remove_node(dst)
        start_traceroute(cmd, tracert_socket)
    end
    #send it forward
end

def handle_traceroute(message)
    arr = message.split(' ')

    type = arr[0]
    tag = arr[1]
    /(.*)->(.*)/.match(tag)
    src = $1
    dst = $2
   
    
    #---handling

    if(type == "TRACER" and src==$my_hostname)  #trace successful
        #return success
        return "trace_complete"
    elsif(type == "TRACER" and not(src == $my_hostname))
        #forward packet to src
        nextnode = $routing_table[src].hostname
        begin
            sock = TCPSocket.new($my_links[nextnode], $port-3)
            sock.write(message)
            sock.close
            return
        rescue Errno::ECONNREFUSED
            #---
        end
    elsif(type == "TRACE" and dst == $my_hostname)  
        #append & send TRACER back to src
        nextnode = $routing_table[src].hostname
        begin
            sock = TCPSocket.new($my_links[nextnode], $port-3)
            sock.write(message[0..4] + "R" + message[5..message.length] + " #{$my_hostname}=>#{Time.now.to_f}")
            sock.close
            return
        rescue Errno::ECONNREFUSED
            #---
        end
    elsif(type == "TRACE" and not(dst == $my_hostname))
        #append to message and forward to dst
        nextnode = $routing_table[dst].hostname
    end
        begin
            sock = TCPSocket.new($my_links[nextnode], $port-3)
            sock.write(message + " #{$my_hostname}=>#{Time.now.to_f}")
            sock.close
            return
        rescue Errno::ECONNREFUSED
            #---
        end
    return
end
# --- perform initialization tasks ---

#-> call update_costs() for the first time, propagate neighbor array
#-> identify hostname of self

init()

update_costs()
update_routing_table($network, $me_node)
#dump_table()
#exit()

serv_socket = TCPServer.new('',$port)
serv_socket.listen(15)   #backlog of 15

ping_socket = TCPServer.new('',$port-1)
ping_socket.listen(15)  #backlog of 15

msg_socket = TCPServer.new('',$port-2)
msg_socket.listen(15)   #backlog of 15

tracert_socket = TCPServer.new('',$port-3)
tracert_socket.listen(15)

#!!!
sleep(1)       #make sure all other nodes are listening?

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
        #puts message
        conn.close()
        
        #if it's an advertisement
        
        if message[0..4] == "FLOOD"
            flood(message)
        end

        if message[0..6] == "CIRCUIT"
            handle_circuit(message)        
        end
    

    rescue Errno::EAGAIN,Errno::EWOULDBLOCK
        #nothing in queue!
    end

    #---handle received pings---
    begin
        conn = ping_socket.accept_nonblock  #accept a connection if any in queue
        message = conn.recv($packet_size)
        #puts message
        conn.close()
        
        #if it's an advertisement
        
        if message[0..3] == "PING"
            handle_ping(message)
        end
    

    rescue Errno::EAGAIN,Errno::EWOULDBLOCK
        #nothing in queue!
    end

    #---handle received TRACEs---
    begin
        conn = tracert_socket.accept_nonblock  #accept a connection if any in queue
        message = conn.recv($packet_size)
        #puts message
        conn.close()
        handle_traceroute(message)
          

    rescue Errno::EAGAIN,Errno::EWOULDBLOCK
        #nothing in queue!
    end

    #---handle received SENDMSGs---
    begin
        conn = msg_socket.accept_nonblock  #accept a connection if any in queue
        message = conn.recv($packet_size)
        #puts message
        conn.close()
        handle_sendmsg(message)
          

    rescue Errno::EAGAIN,Errno::EWOULDBLOCK
        #nothing in queue!
    end


	#--- check for user input (i.e. message sending) ---
    
    begin

        cmd = $stdin.read_nonblock(80) #max command size = 80 chars
        #puts "cmd=#{cmd}"    
        #process command
        if(cmd[0..6] == "SENDMSG")
            #handle SENDMSG
            start_sendmsg(cmd, msg_socket)
        elsif (cmd[0..3] == "PING")
            #handle PING
            start_ping(cmd, ping_socket)
        elsif(cmd[0..9] == "TRACEROUTE")
            #handle TRACEROUTE
            start_traceroute(cmd, tracert_socket)
        else
            puts "Invalid command."
        end

    rescue Errno::EWOULDBLOCK, Errno::EAGAIN
        #if no input
    end
end
