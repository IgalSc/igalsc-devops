1. Install rclone 

sudo apt update && sudo apt install rclone

2. configure your source and destination accounts

rclone config

3. assuming you move directories from S3 to S3, create subfolders.txt with the following structure:

/subfolder1/subfolder2/
/subfolder3/subfolder4/

4. use large isntance (c5n.2xl or bigger)

5. run the rclone using the shell script:

./rclone_folder_move.sh --dest-bucket $DESTINATION_BUCKET -m move -p 16 -c 32 $SOURCE_ACCOUNT $SOURCE_BUCKET $DESTINATION_ACCOUNT subfolders.txt
