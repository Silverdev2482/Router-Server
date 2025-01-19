#!/bin/sh

root_directory=/srv/shares
user=$2
directory="${root_directory}/Users/${2^}"

remove_acls_chown () {
  setfacl -b $1
  setfacl -Rb $1

  chmod -r 2700 $1

  chown share:share $1
  chown -R share:share $1
}


set_mask () {
  setfacl -Rm m::rwx $1
  setfacl -Rdm m::rwx $1
}

set_user () {
  setfacl -Rm u:$1:rwx $2
  setfacl -Rdm u:$1:rwx $2
}

set_group_private () {
  setfacl -Rm g:share:--- $1
  setfacl -Rdm g:share:--- $1
  chmod -r 2700 $_directory
}

set_group_share_read () {
  setfacl -Rm g:share:r-x $1
  setfacl -Rdm g:share:r-x $1
}

set_group_share_write () {
  setfacl -Rm g:share:rwx $1
  setfacl -Rdm g:share:rwx $1
  chmod -r 2770 $1
}

set_public () {
  remove_acls $1
  set_mask $1
  set_user share $1
  set_group_share_write $1
}

set_public_flat () {
  setfacl -m m::rwx $1
  setfacl -dm m::rwx $1
  setfacl -m u:share:rwx $1
  setfacl -dm u:share:rwx $1
  setfacl -m g:share:rwx $1
  setfacl -dm g:share:rwx $1
}

set_read_only () {
  setfacl -m m::rwx $1
  setfacl -dm m::rwx $1
  setfacl -m u:share:r-x $1
  setfacl -dm u:share:r-x $1
  setfacl -m g:share:r-x $1
  setfacl -dm g:share:r-x $1
}

setup_user_without_group () {
  id=$(id -u $1 2>/dev/null)
    if [[ $? -eq 0 ]]
    then
      echo "Setting up permissions for $1"
    else
      echo "User $1 does not exist, please create them before setting ACLs"
      exit 1
    fi

    mkdir -p $2
    remove_acls $2
    set_mask $2
    set_user $1 $2
}

case "$1" in
  public_user)
    setup_user_without_group $user $directory
    set_group_share_read $directory 
    echo "Set permissions for $user with read access for other users"
    ;;
   private_user)
    setup_user_without_group $user $directory
    set_group_private $directory
    echo "Set permissions for $user with no access to other users"
    ;;
  root)
    echo "Setting permissions for root folder"

    setfacl -b $root_directory
    chown share:share $root_directory
    chmod 2770 $root_directory

    set_public_flat $root_directory

    # Sets the acls on all the directories inside /srv/shares except for Users, recursively
    export -f remove_acls
    export -f set_public
    export -f remove_acls
    export -f set_mask
    export -f set_user
    export -f set_group_share_write
    find /srv/shares/ -maxdepth 1 -type d ! -path /srv/shares/Users -execdir bash -c 'remove_acls "$0"' {} \;
    find /srv/shares/ -maxdepth 1 -type d ! -path /srv/shares/Users -execdir bash -c 'set_public "$0"' {} \;
    set_read_only $root_directory/Users

    echo "Set permissions for the root directory and contents."
    echo "This part of the script does not handle the individual"
    echo "user directories so make sure to run it on those also."
    ;;

  *)
    echo "./user-acl.sh { root | public_user | private_user } <user> <directory>"
    ;;
esac
