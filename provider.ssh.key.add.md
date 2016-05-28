# For KIMSUFI

Go to kimsufi manager
https://www.kimsufi.com/en/manager/#/login

Once loged in, click on top righ corner (your account name).
And click on "SSH keys"

Once on "SSH keys" page, click "add a new SSH key"

Set the "last name" as you want
In key you must put the content of you pulic key
"cat ${HOME}/.ssh/id_{ed25519,rsa,ecdsa}.pub"

If the key is correct the encryption type will be display (RSA DSA ECDSA ED25519)
Finally, click on Confirm

You should see a new line with the new added public key


# For online.net Dedibox
#TODO
