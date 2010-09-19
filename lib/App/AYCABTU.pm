package App::AYCABTU;
use App::AYCABTU::OO -base;
use 5.008003;

our $VERSION = '0.10';

use YAML::XS;
use Getopt::Long;

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
    my $action = "action_" . $self->action;
    die "Can't perform action '" . $self->action . "'"
        unless $self->can($action);
    for my $entry (@{$self->repos}) {
        $self->$action($entry);
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
            $self->names([split ',', $names]);
        },
        "all" => sub { $self->all(1) },
        "help" => \&help,
    );
    die "Can't locate aybabtu config file '${\ $self->file}'. Use --file=... option"
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
        if ($repo =~ /.*\/(.*).git$/) {
            $entry->{name} = $1;
        }
        else {
            $entry->{name} = '';
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
}

sub action_status {
    my $self = shift;
    my $entry = shift;
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
