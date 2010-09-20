package App::AYCABTU;
use App::AYCABTU::OO -base;
use 5.008003;

our $VERSION = '0.01';

use Getopt::Long;
use YAML::XS;
use Capture::Tiny 'capture';

has config => [];

has file => 'AYCABTU';
has action => 'update';
has tags => [];
has names => [];
has all => 0;

has repos => [];

sub run {
    my $self = shift;
    $self->get_options(@_);
    $self->read_config();
    $self->select_repos();
    my $action = $self->action;
    my $method = "action_$action";
    print "Can't perform action '$action'\n" && return
        unless $self->can($method);
    for my $entry (@{$self->repos}) {
        $self->$method($entry);
    }
}

sub get_options {
    my $self = shift;
    GetOptions(
        "update" => sub { $self->action('update') },
        "status" => sub { $self->action('status') },
        "list" => sub { $self->action('list') },
        "file=s" => sub { $self->file($_[1]) },
        "tags=s" => sub {
            my $tags = $_[1] or return;
            push @{$self->tags}, [split ',', $tags];
        },
        "names=s" => sub {
            my $names = $_[1] or return;
            push @{$self->names}, split ',', $names;
        },
        "all" => sub { $self->all(1) },
        "help" => \&help,
    );
    print "Can't locate aybabtu config file '${\ $self->file}'. Use --file=... option\n" and exit
        if not -e $self->file;
}

sub read_config {
    my $self = shift;
    my $config = YAML::XS::LoadFile($self->file);
    $self->config($config);
    die $self->file . " must be a YAML sequence of mapping"
        if (ref($config) ne 'ARRAY') or grep {
            ref ne 'HASH'
        } @$config;
    my $count = 1;
    for my $entry (@$config) {
        my $repo = $entry->{repo}
            or die "No 'repo' field for entry $count";

        $entry->{_num} = $count++;

        $entry->{name} ||= '';
        if ($repo =~ /.*\/(.*).git$/) {
            $entry->{name} = $1;
        }

        $entry->{type} ||= '';
        if ($repo =~ /\.git$/) {
            $entry->{type} = 'git';
        }
        elsif ($repo =~ /svn/) {
            $entry->{type} = 'svn';
        }

        $entry->{tags} ||= '';
    }
}

sub select_repos {
    my $self = shift;

    my $config = $self->config;
    my $repos = $self->repos;
    my $names = $self->names;

    my $last = 0;
OUTER:
    for my $entry (@$config) {
        last if $last;
        next if $entry->{skip};
        $last = 1 if $entry->{last};

        if ($self->all) {
            push @$repos, $entry;
            next;
        }
        if (@$names) {
            if (grep {$_ eq $entry->{name}} @$names) {
                push @$repos, $entry;
                next;
            }
        }
        for my $tags (@{$self->tags}) {
            if ($tags) {
                my $count = scalar grep {$entry->{tags} =~ /\b$_\b/} @$tags;
                if ($count == @$tags) {
                    push @$repos, $entry;
                    next OUTER;
                }
            }
        }
    }
}

sub action_update {
    my $self = shift;
    my $entry = shift;
    my ($repo, $name, $type) = @{$entry}{qw(repo name type)};
    print "Can't update $repo. No name.\n" && return
        unless $name;
    print "Can't update $name. Unknown type.\n" && return
        unless $type;
    print "Can't update $name. Type $type not yet supported.\n" && return
        unless $type eq 'git';
    print "Updating $name... ";
    $self->update_git($entry);
    print "\n";
}

sub update_git {
    my $self = shift;
    my $entry = shift;
    my ($repo, $name) = @{$entry}{qw(repo name)};
    if (-d $name and -d "$name/.git") {
        my ($o, $e) = capture { system("cd $name; git pull") };
        print $o, $e unless $o eq "Already up-to-date.\n";
        print "Done";
    }
    else {
        print "Skipped";
    }
}

sub action_status {
    my $self = shift;
    my $entry = shift;
    print "Action 'status' not yet implemented";
}

sub action_list {
    my $self = shift;
    my $entry = shift;
    print YAML::XS::Dump($entry);
}

sub help {
    print <<'...';
Usage:
    aycabtu [ options ]
    
Options:
    --file=file         # aycabtu config file. Default: 'AYCABTU'

    [--update | --status | --list]   # Action. Default: 'update'
        update          # Checkout or update the selected repos
        status          # Get status info on the selected repos
        list            # List the selected repos

    --all               # Use all the repos in the config file
    --tags=tags         # Select repos matching all the tags
                        # Option can be used more than once
    --names=names       # The names of the repos to select

...
    exit;
}

1;

=encoding utf8

=head1 NAME

App::AYCABTU - All Your Codes Are Belong To Us

=head1 SYNOPSIS

    > aycabtu --help

=head1 DESCRIPTION

This module installs a program called L<aycabtu>, that can be used to
manage all of the code repositories that you are interested in.

=head1 STATUS

This is a very early release. Only the a couple features are
implemented, and somewhat poorly.

See L<http://github.com/ingydotnet/aycabt-
ingydotnet/blob/master/AYCABTU> for an example of how to
configure AYCABTU.

Stay tuned. Things should be much better soon.

=head1 RESOURCES

CPAN: L<http://search.cpan.org/dist/App-AYCABTU/>

GitHub: L<http://github.com/ingydotnet/app-aycabtu-pm>

=head1 AUTHOR

Ingy döt Net <ingy@cpan.org>

=head1 COPYRIGHT

Copyright (c) 2010. Ingy döt Net

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See L<http://www.perl.com/perl/misc/Artistic.html>

=cut
