Directions-------------------------------------------------------

Unzip all files into the host's home directory. (/home/core/)
Run gen_weights and have output file named 'costs.csv' in the home directory.

Run rsa.rb: 'ruby rsa.rb <number of nodes>'
In our case, that number would be 12.
This generates rsa keys for use in our security extension.

***Make sure that the files use the correct interfaces***
---> we noticed a typo in a couple of the files resulting in bad addresses

Settings can be specified in 'global.cfg'

Execute /home/core/run.sh on each node in the network from that node's 
starting directory.

Each node's respective routing table will be dumped to 'table.dump' in their 
starting directory.

Runtime information can be viewed in each node's terminal.

-----------------------------------------------------------------

Our code is divided into two files: node.rb and graph.rb. graph.rb provides
an implementation of a graph used for routing table calcuations (dijkstra's). 
node.rb handles the bulk of the processing - initialization, advertising to 
other nodes, handling control messages from other nodes, populating the graph structure, and updating/dumping the routing table.

We have a server loop that will periodically check for timing delay 
thresholds - when it is time to update costs from the costs file or broadcast 
packets again. In this loop we attempt to process one message per iteration 
using non-blocking sockets - our max queue is presently 15 - we have not had 
a need for more.

To reduce network traffic and loads on individual nodes, we implemented a
kind of probabilistic flooding. If advertisement packets have been seen
before, they are only forwarded to neighbors 50% of the time. This is
necessary to ensure that new nodes that pop up still receive all of the
advertisements without the severe delays that we were previously having.

We implemented a framework for establishing virtual circuits. A control 
message is constructed containing the source node and the destination node. 
At all nodes in the shortest path between the source and destination, a 
Circuit struct will be created and added to the list of Circuits at each 
respective node. These structs will be used to keep track of the network's 
circuits.

The VCs are used in message passing - the SENDMSG command. A VC is set up,
the message is passed to the destination through the circuit, then the VC
is torn down in reverse network order.

For PING and TRACEROUTE, we wanted readings to be more accurate so we 
opted not to establish a VC for them. Setting a VC up takes clock cycles
which could affect the output time.

For User commands and output, we've opted to primarily use hostnames, as
they are less ambiguous than IP addresses/interfaces: to trace the route
to a node n20, the command is "TRACEROUTE n20".

We've been experimenting with advertisement broadcast frequency to try
to reduce the time it takes for a new node's presence to become known 
across the network. Right now it takes a few seconds at best, so don't
give up if you see HOST UNREACHABLE right away. :)

Note: Our routing tables initially assume the presence of the node's 
immediate neighbors, and corrects itself if any are down while trying to 
reach them.

Our security extension was to prevent a malicious node from tampering with
message data. To do this, we implemented RSA digital signatures for all 
SENDMSG data. 

We black-boxed key distribution, as it's out of scope of this project. We
handled it in the same way that edge costs are determined - a file is 
parsed by each node to find its relevant data.

Our implementation will calculate the SHA256 hash of the message data, then
sign the hash with the node's private key. Upon receival, the destination
node decrypts the signature with the public key of the sender and compares
it with the hash of the message data. If they are equal, then the message
signature is verified. Otherwise, verification fails.

This provides message security and ensures that only the sender could have
signed a given message.

Other things, such as broadcasts and pings, could be extended to also include
digital signatures. Doing this would minimize the risk of any rogue node -
nodes could only broadcast their own false packets instead of being able
to modify the advertisements of others.
