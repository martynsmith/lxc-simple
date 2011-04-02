# lxc - Wrapper around lxc utils to make managing containers easier
# Copyright © 2011 Shoptime Software
#
# This package is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2 of the License, or (at your option) any later version.
#
# This package is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this package; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301 USA

package LXC::Commands;
use warnings;
use strict;

=head1 NAME

LXC::Commands - commands for LXC

=head1 DESCRIPTION

Contains routines that back the LXC commands. Normally, you would access these
through the 'lxc' script, but you can include this module and use them directly
if you wish.

=head1 METHODS

=cut


=head2 create

Creates a new container.

Takes a hash with the following keys:

=over 4

=item name

The name of the container to create.

=back

=cut

sub create {
    my ($class, %args) = @_;
    my $name = $args{name} || die "Must specify a name for the container to be created\n";

    system('lxc-create',
        '-n', $name,                    # TODO: check for invalid name first?
        '-f', '/etc/lxc/lxc.conf',      # TODO: this is for networking stuff
        '-t', 'ubuntu',                 # TODO: naturally, should be configurable
    );

    # TODO /var/lib/lxc should be configurable
    if ( $args{bindmount_home} ) {
        my $lxc_root          = '/var/lib/lxc/';
        my $container_cfgroot = $lxc_root . $name . '/';
        my $container_root    = $lxc_root . $name . '/rootfs/';
        open(FH, '>>', $container_cfgroot . 'fstab') or die $!;
        printf FH "/home           %s         auto bind 0 0\n", $container_root . 'home';
        close(FH);
    }

    if ( $args{install_user} ) {
        # TODO naturally, we could grab this information from a config file
        if ( exists $ENV{SUDO_USER} ) {
            my $user = $ENV{SUDO_USER};
            # TODO find user line in /etc/passwd, append to container's /etc/passwd
            # TODO find user line in /etc/shadow, append to container's /etc/shadow
            # TODO find group line in /etc/group, append to container's /etc/group
        }
        else {
            print "Could not establish what user to install, skipping\n";
        }
    }
}


=head2 destroy

Destroys a container, stopping it first if necessary.

Takes a hash with the following keys:

=over 4

=item name

The name of the container to destroy.

=back

=cut

sub destroy {
    my ($class, %args) = @_;
    my $name = $args{name} || die "Must specify what container to destroy\n";
    $class->check_valid_container($name);

    if ( $class->status(name => $name, brief => 1) eq 'running' ) {
        $class->stop(name => $name);
    }

    print "Destroying test... ";
    system('lxc-destroy',
        '-n', $name,
    );
    print "done\n";
}


=head2 start

Starts a container.

Takes a hash with the following keys:

=over 4

=item name

The name of the container to start.

=back

=cut

sub start {
    my ($class, %args) = @_;
    my $name = $args{name} || die "Must specify what container to start\n";
    $class->check_valid_container($name);

    die "Container '$name' IS started\n" if $class->status(name => $name, brief => 1) eq 'running';

    print "Starting $name... ";
    system('lxc-start',
        '-n', $name,
        '-d',
    );
    system('lxc-wait',
        '-n', $name,
        '-s', 'RUNNING',
    );
    print "done\n";
}


=head2 stop

Stops a container.

Takes a hash with the following keys:

=over 4

=item name

The name of the container to stop.

=back

=cut

sub stop {
    my ($class, %args) = @_;
    my $name = $args{name} || die "Must specify what container to stop\n";
    $class->check_valid_container($name);

    die "Container '$name' IS stopped\n" if $class->status(name => $name, brief => 1) eq 'stopped';

    print "Stopping $name... ";
    system('lxc-stop',
        '-n', $name,
    );
    system('lxc-wait',
        '-n', $name,
        '-s', 'STOPPED',
    );
    print "done\n";
}


=head2 status

Gives status information about one or all containers.

Takes a hash with the following keys:

=over 4

=item name

The name of the container to get status information for (optional).

=item brief

Boolean, whether to output brief (machine readable) information (optional).

=back

=cut

sub status {
    my ($class, %args) = @_;

    if ( $args{name} ) {
        my $name = $args{name};
        $class->check_valid_container($name);

        if ( $args{brief} ) {
            my $status = `lxc-info -n $name`; # TODO bad evil, use tap instead
            if ( $status =~ m{^'\Q$name\E' is ([A-Z]+)$} ) {
                return lc $1;
            }
            die "Could not get status for container\n";
        }

        # TODO would be nice to provide more detail here
        system('lxc-info',
            '-n', $name
        );
        return;
    }

    # Status for all containers
    for my $dir (</var/lib/lxc/*>) {
        if ( -d $dir && $dir =~ m{/([^/]+)$} ) {
            system('lxc-info',
                '-n', $1,
            );
        }
    }
}


=head2 check_valid_container

Given a container name, checks if the name refers to an existing container.

=cut

sub check_valid_container {
    my ($class, $name) = @_;
    die "No such container '$name'\n" unless -d '/var/lib/lxc/' . $name;
}

=head1 AUTHOR

Shoptime Software

=cut

1;