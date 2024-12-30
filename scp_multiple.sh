#!/bin/bash

ACCESS_FILE="access_details.txt"

LOCAL_FILE="/home/ai/Desktop/AnsibleVS/Ansible_ubuntu/test_scrap"

REMOTE_DIR="/sec/root/"

PASSWORD="segfault"

DECRYPT_PASSWORD="123456789hgfdrhjkl"

FOLDER_NAME=$(basename "$LOCAL_FILE")

echo "Remote path to copy: $REMOTE_DIR$FOLDER_NAME"

while IFS= read -r line
do
  if [[ -n "$line" ]]; then
    SSH_OPTIONS=$(echo "$line" | sed 's/^ssh //; s/ root@.*//')

    HOST=$(echo "$line" | sed 's/^.*root@//')

    echo "Copying folder to $HOST..."

    expect <<EOF
      set timeout 10
      # Perform SCP transfer (copy the folder, not a file)
      spawn scp -r $SSH_OPTIONS -i ~/.ssh/id_rsa "$LOCAL_FILE" "root@$HOST:$REMOTE_DIR"
      expect {
        "password:" { send "$PASSWORD\r"; exp_continue }
        eof
      }
EOF

    echo "SSH into $HOST to set permissions and run script..."
    expect <<EOF
      set timeout 10
      spawn ssh -o "SetEnv SECRET=dfCGqhdfLNxHmGGaZBKPHgnU" root@$HOST
      expect {
        "password:" { send "$PASSWORD\r"; exp_continue }
      }

      
      send "ls -l $REMOTE_DIR\r"
      expect "\$ "

      send "chmod -R +x $REMOTE_DIR$FOLDER_NAME\r"
      expect "\$ "

      send "openssl enc -d -aes-256-cbc -in /sec/root/test_scrap/scrap.py.enc -pbkdf2 | python3\r"
      expect "enter AES-256-CBC decryption password:" { send "$DECRYPT_PASSWORD\r"; exp_continue }
      expect "\$ "

      set timeout 30

      send "bash $REMOTE_DIR$FOLDER_NAME/test_scrip.sh\r"
      expect "\$ "
EOF

    if [[ $? -eq 0 ]]; then
      echo "Successfully copied, set folder permissions, decrypted and ran scripts on $HOST."
    else
      echo "Failed to copy folder, set permissions, decrypt, or run the script on $HOST."
    fi
  fi
done < "$ACCESS_FILE"

echo "All folders have been copied, folder permissions set, scripts decrypted and executed."
