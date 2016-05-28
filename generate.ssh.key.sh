# Generate ssh key on you computer

# Choose the type of encryption
ssh-keygen -t ed25519
ssh-keygen -b 4096 -t rsa
ssh-keygen -b 521 -t ecdsa

# Verify 
cat ${HOME}/.ssh/id_{ed25519,rsa,ecdsa}.pub
