require 'openssl'

# generates keys for each node in the routing table keys and stores the public and private keys in file
def generate_keys(count)
    # generating the keys and storing them in hash tables
    public_file = File.new('/home/core/public.keys', 'w')
    private_file = File.new('/home/core/private.keys', 'w')
    public_keys = {}
    private_keys = {}

    i = 1
    while i <= count
        #rsa_key = OpenSSL::PKey::RSA.new(2048)
        rsa_key = OpenSSL::PKey::RSA.new(1024)
        cipher = OpenSSL::Cipher::Cipher.new('des3')
        password = "n#{i}"
        #password = " "
        private_key = rsa_key.to_pem(cipher, password)
        public_key = rsa_key.public_key.to_pem
        public_keys[password] = public_key
        private_keys[password] = private_key
        i = i+1
    end

    # dumping the hash tables to files
    #puts public_keys.inspect
    public_file.write(Marshal.dump(public_keys))
    private_file.write(Marshal.dump(private_keys))

    public_file.close
    private_file.close
end

#puts ARGV[0]
if ARGV[0] == nil or ARGV[0].to_i < 1
    puts "Invalid argument count."
else
    generate_keys(ARGV[0].to_i)
end
