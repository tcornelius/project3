# This is a class that will provide the graph to develop the forwarding table.
#
# By Shyam Patel and Tom Cornelius


# This is the node class used in the graph. It will be produced after a broadcast is received.
class Graph_Node

	# The hostname and version are of the source node.
	attr_accessor :hostname, :version

	def initialize(hostname, version)
		@hostname = hostname
		@version = version
	end

	def to_s
		return @ip_address
	end

end

class Graph
	# getters/setters
	# vertices is the list of edges or vertices in the graph
	# the edges is a hash map that stores the list of neighbors and costs. The neighbor ip-address is going to be used as the key and the cost will be the value.

	attr_accessor :vertices, :dijkstra

	def initialize()
		@vertices = {}
	end

	def add_node(host, edges)
		@vertices[host] = edges
	end

	def get_smallest_neighbor(hash)
		h2 = hash.clone
		x = h2.sort_by {|k, v| v}[0][0]
		hash.delete(x)
		return x
	end

	def dijkstra(start, finish)
		max_int = (2**(0.size * 8 -2) -1)
		dist = {}
		prev = {}
		hosts = {}

		@vertices.each do | key, value |
#			puts key.ip_address
			if key.hostname == start.hostname
				dist[key] = 0
				hosts[key] = 0
			else
				dist[key] = max_int
				hosts[key] = max_int
			end
			prev[key] = nil
		end

		while hosts
			smallest = get_smallest_neighbor(hosts)

			if smallest.hostname == finish.hostname
				path = []
				while prev[smallest]
					path.push(smallest)
					smallest = prev[smallest]
				end
				return path
			end

			if smallest == nil or dist[smallest] == max_int
				break            
			end
			@vertices[smallest].each do | neighbor, cost |
				new_cost = dist[smallest] + @vertices[smallest][neighbor]
				if new_cost < dist[neighbor]
					dist[neighbor] = new_cost
					prev[neighbor] = smallest
					hosts[neighbor] = new_cost
				end
			end
		end
		# puts "--------------------"
		return dist
	end

end

# gr = Graph.new
# a = Graph_Node.new('A', -1, -1)
# b = Graph_Node.new('B', -1, -1)
# c = Graph_Node.new('C', -1, -1)
# d = Graph_Node.new('D', -1, -1)
# e = Graph_Node.new('E', -1, -1)
# f = Graph_Node.new('F', -1, -1)
# g = Graph_Node.new('G', -1, -1)
# h = Graph_Node.new('H', -1, -1)

# gr.add_node(a, {b => 7, c => 8})
# gr.add_node(b, {a => 7, f => 2})
# gr.add_node(c, {a => 8, f => 6, g => 4})
# gr.add_node(d, {f => 8})
# gr.add_node(e, {h => 1})
# gr.add_node(f, {b => 2, c => 6, d => 8, g => 9, h => 3})
# gr.add_node(g, {c => 4, f => 9})
# gr.add_node(h, {e => 1, f => 3})

# gr.dijkstra(a, h).each{|n|
# 	puts n.to_s
# }
# puts (2**(0.size * 8 -2) -1)

