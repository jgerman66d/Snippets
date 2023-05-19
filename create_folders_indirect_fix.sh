# This script is designed to mount a specified Google Cloud Storage bucket to a local directory.
# It does so by creating a list of all unique directory names within the bucket, then creating
# those directories in the local filesystem, effectively 'mounting' the bucket structure.

# Default mount point is the "mnt" subdirectory within the /var/file_mounts directory
MOUNT_PT=${1:-/var/file_mounts/mnt}

# The second argument is the name of the bucket to be mounted
BUCKET_ID=$2

# The third argument specifies whether the temporary file created by the script should be deleted
# Defaults to 'y' (yes)
DEL_OUTPUTFILE=${3:-y}

# This script makes use of Google's gsutil command-line tool to interact with Cloud Storage

# The first message that will be printed to the console once the script starts executing
echo "Discovering $BUCKET_ID"

# This is the name of a temporary file that will store the list of directories in the bucket
OUTPUTFILE=directory_names_to_create.txt

# This command retrieves the list of all objects in the specified bucket, including objects in subdirectories
# The ** at the end of the bucket name means to recurse through all directories within the bucket
gsutil ls -r gs://$BUCKET_ID/** | while read BUCKET_OBJECT
do   
    # This command prints the directory part of each object's pathname
    dirname "$BUCKET_OBJECT"
done | sort -u > $OUTPUTFILE  # The output is sorted and duplicates are removed, then written to the temporary file

# The next message to be printed to the console
echo "Compiling list of directories to create"

# This command reads the list of directories from the temporary file
cat $OUTPUTFILE | while read DIR_NAME
do
    # This command removes the bucket name from the start of each directory, leaving just the path within the bucket
    LOCAL_DIR=`echo "$DIR_NAME" | sed "s=gs://$BUCKET_ID/==" | sed "s=gs://$BUCKET_ID=="`

    # This command forms the path where the bucket directory will be 'mounted' in the local filesystem
    TARGET_DIRECTORY="$MOUNT_PT/$LOCAL_DIR"

    # This conditional block checks if the directory already exists in the local filesystem
    if ! [ -d "$TARGET_DIRECTORY" ]
    then
	    # If the directory does not exist, it is created
        echo "Creating $TARGET_DIRECTORY"
        mkdir -p "$TARGET_DIRECTORY"
    fi
done

# This conditional block checks if the script has been instructed to delete the temporary file
if [ $DEL_OUTPUTFILE = "y" ]
then
    # If so, the temporary file is deleted
    rm $OUTPUTFILE
fi

# The final message to be printed to the console, indicating that the script has finished executing
echo "Directory Structure is updated"
