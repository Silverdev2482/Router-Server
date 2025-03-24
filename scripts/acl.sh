#!/bin/sh

root_directory=/srv/shares
user=$2
directory="${root_directory}/Users/${2^}"

reset_acls_flat () {
  setfacl -b $1
  chown root:root $1
  chmod 2770 $1
  setfacl -m m::rwx $1
  setfacl -dm m::rwx $1
}

reset_acls_recursive () {
  setfacl -b $1
  setfacl -Rb $1

  chown root:root $1
  chown -R root:root $1

  chmod 2770 -R $1
  setfacl -Rm m::rwx $1
  setfacl -Rdm m::rwx $1
}

set_user_recursive () {
  setfacl -Rm u:$1:rwx $2
  setfacl -Rdm u:$1:rwx $2
}

set_private_recursive () {
  setfacl -Rm g:share:--- $1
  setfacl -Rdm g:share:--- $1
}

set_public_read_only_flat () {
  setfacl -m g:share:r-x $1
  setfacl -dm g:share:r-x $1
}

set_public_read_only_recursive () {
  setfacl -Rm g:share:r-x $1
  setfacl -Rdm g:share:r-x $1
}

set_public_writable_flat () {
  setfacl -m g:share:rwx $1
  setfacl -dm g:share:rwx $1
}

set_public_writable_recursive () {
  setfacl -Rm g:share:rwx $1
  setfacl -Rdm g:share:rwx $1
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
    reset_acls_recursive $2
    set_user_recursive $1 $2
}

case "$1" in
  public_user)
    setup_user_without_group $user $directory
    set_public_read_only_recursive $directory 
    echo "Set permissions for $user with read access for other users"
    ;;
  private_user)
    setup_user_without_group $user $directory
    set_private_recursive $directory
    echo "Set permissions for $user with no access to other users"
    ;;
  root)
    echo "Setting permissions for root folder"
    
    mkdir -p $root_directory/Users
    mkdir -p $root_directory/Groups

    reset_acls_flat $root_directory
    set_public_writable_flat $root_directory

    # Sets the acls on all the directories inside /srv/shares except for Users, recursively
    export -f reset_acls_recursive
    export -f set_public_writable_recursive
    find /srv/shares/ -mindepth 1 -maxdepth 1 ! -path /srv/shares/Users ! -path /srv/shares/Groups -execdir bash -c 'reset_acls_recursive "$0"; set_public_writable_recursive "$0"' {} \;

    reset_acls_flat  $root_directory/Users
    reset_acls_flat  $root_directory/Groups
    set_public_read_only_flat $root_directory/Users
    set_public_read_only_flat $root_directory/Groups

    echo "Set permissions for the root directory and contents."
    echo "This part of the script does not handle the individual"
    echo "user directories so make sure to run it on those also."
    ;;

  *)
    echo "./user-acl.sh { root | public_user | private_user } <user>"
    ;;
esac
