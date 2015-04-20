Directions-------------------------------------------------------

Unzip all files into the host's home directory. (/home/core/)
Run gen_weights and have output file named 'costs.csv' in the home directory.

Settings can be specified in 'global.cfg'

Execute /home/core/run.sh on each node in the network from that node's starting directory.

Each node's respective routing table will be dumped to 'table.dump' in their starting
directory.

Runtime information can be viewed in each node's terminal.

-----------------------------------------------------------------

Our code is divided into two files: node.rb and graph.rb. graph.rb provides an
implementation of a graph used for routing table calcuations (dijkstra's). node.rb
handles the bulk of the processing - initialization, advertising to other nodes, handling control messages from other nodes, propagating the graph structure, and updating/dumping the routing table.

We have a server loop that will periodically check for timing delay thresholds - when
it is time to update costs from the costs file or broadcast packets again. In this loop we attempt to process one message per iteration using non-blocking sockets - our
max queue is presently 15 - we have not had a need for more.

We implemented a framework for establishing virtual circuits. A control message is
constructed containing the source node and the destination node. At all nodes in the
shortest path between the source and destination, a Circuit struct will be populated
and added to the list of Circuits at each respective node. These structs will be used
to keep track of the network's circuits.


