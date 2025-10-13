#!/bin/sh

root_directory=/srv/shares
user=$2
directory="${root_directory}/Users/${2^}"

rd_setfacl () {
  setfacl -Rm $1 $2
  setfacl -Rdm $1 $2
}

d_setfacl () {
  setfacl -m $1 $2
  setfacl -dm $1 $2
}

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
  rd_setfacl m::rwx $1
}

set_private_recursive () {
  rd_setfacl g:share:--- $1
  rd_setfacl g:guest:--- $1
}

set_public_read_only_flat () {
  d_setfacl g:share:r-x $1
  d_setfacl g:guest:--x $1
}

set_public_read_only_recursive () {
  rd_setfacl g:share:r-x $1
  rd_setfacl g:guest:--x $1
}

set_public_writable_flat () {
  d_setfacl g:share:rwx $1
  d_setfacl g:guest:--x $1
}

set_public_writable_recursive () {
  rd_setfacl g:share:rwx $1
  rd_setfacl g:guest:--x $1
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
    rd_setfacl u:$1:rwx $2
}

case "$1" in
  public_user)
    setup_user_without_group $user $directory
    set_public_read_only_recursive $directory what is the non default acl called?
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
    export -f rd_setfacl
    export -f reset_acls_recursive
    export -f set_public_writable_recursive
    find /srv/shares/ -mindepth 1 -maxdepth 1 ! -path /srv/shares/Users ! -path /srv/shares/Groups -execdir bash -c 'reset_acls_recursive "$0"; set_public_writable_recursive "$0"' {} \;

    rd_setfacl u:borg:rwx /srv/shares

    reset_acls_flat $root_directory/Users
    reset_acls_flat $root_directory/Groups
    set_public_read_only_flat $root_directory/Users
    set_public_read_only_flat $root_directory/Groups

    echo "Set permissions for the root directory and contents."
    echo "This part of the script does not handle the individual"
    echo "user and group directories so don't forget about them."
    ;;

  *)
    echo "./user-acl.sh { root | public_user | private_user } <user>"
    ;;
esac
