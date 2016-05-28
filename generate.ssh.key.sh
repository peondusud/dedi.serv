# Generate ssh key on you computer

# Choose the type of encryption
ssh-keygen -t ed25519
ssh-keygen -b 4096 -t rsa
ssh-keygen -b 521 -t ecdsa

# Verify 
cat ${HOME}/.ssh/id_{ed25519,rsa,ecdsa}.pub

# Once you have generated a key pair, you will need to copy the public key to the remote server so that it will use SSH key authentication. 
ssh-copy-id -i ~/.ssh/id_{ed25519,rsa,ecdsa}.pub -p 2222 username@remote-server.org
