package App::AYCABTU;
use App::AYCABTU::OO -base;
use 5.008003;

our $VERSION = '0.02';

use Getopt::Long;
use YAML::XS;
use Capture::Tiny 'capture';

has config => [];

has file => 'AYCABTU';
has action => 'list';
has tags => [];
has names => [];
has all => 0;
has quiet => 0;
has verbose => 0;
has args => [];

has repos => [];

my ($prefix, $error, $quiet, $normal, $verbose);

sub run {
    my $self = shift;
    $self->get_options(@_);
    $self->read_config();
    $self->select_repos();
    if (not @{$self->repos}) {
        print STDOUT "No repositories selected. Try --all.\n";
        return;
    }
    my $action = $self->action;
    my $method = "action_$action";
    die "Can't perform action '$action'\n"
        unless $self->can($method);
    for my $entry (@{$self->repos}) {
        ($prefix, $error, $quiet, $normal, $verbose) = ('') x 5;
        $self->$method($entry);
        $verbose ||= $normal;
        $normal ||= $quiet;
        my $msg =
            $error ? $error :
            $self->verbose ? $verbose :
            $self->quiet ? $quiet :
            $normal;
        $msg = "$prefix$msg\n" if $msg;
        print STDOUT $msg;
    }
}

sub get_options {
    my $self = shift;
    GetOptions(
        'update' => sub { $self->action('update') },
        'status' => sub { $self->action('status') },
        'list' => sub { $self->action('list') },
        'file=s' => sub { $self->file($_[1]) },
        'tags=s' => sub {
            my $tags = $_[1] or return;
            push @{$self->tags}, [split ',', $tags];
        },
        'all' => sub { $self->all(1) },
        'quiet' => sub { $self->quiet(1) },
        'verbose' => sub { $self->verbose(1) },
        'help' => \&help,
    );
    no warnings;
    my $names = [
        map {
            s!/$!!;
            if (/^(\d+)-(\d+)?$/) {
                ($1..$2);
            }
            else {
                ($_);
            }
        } @ARGV
    ];
    $self->names($names);
    die "Can't locate aybabtu config file '${\ $self->file}'. Use --file=... option\n"
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
        if (not $entry->{name} and $repo =~ /.*\/(.*).git$/) {
            my $name = $1;
            # XXX This should be configable.
            $name =~ s/\.wiki$/-wiki/;
            $entry->{name} = $name;
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
        my ($num, $name) = @{$entry}{qw(_num name)};
        if (@$names) {
            if (grep {$_ eq $name or $_ eq $num} @$names) {
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
    $self->_check(update => $entry) or return;
    my ($num, $name) = @{$entry}{qw(_num name)};
    $prefix = "$num) Updating $name... ";
    $self->git_update($entry);
}

sub action_status {
    my $self = shift;
    my $entry = shift;
    $self->_check('check status' => $entry) or return;
    my ($num, $name) = @{$entry}{qw(_num name)};
    $prefix = "$num) Status for $name... ";
    $self->git_status($entry);
}

sub action_list {
    my $self = shift;
    my $entry = shift;
    my ($num, $repo, $name, $type, $tags) = @{$entry}{qw(_num repo name type tags)};
    $prefix = "$num) ";
    $quiet = $name;
    $normal = sprintf " %-25s %-4s %-50s", $name, $type, $repo;
    $verbose = "$normal\n    tags: $tags";
}

sub _check {
    my $self = shift;
    my $action = shift;
    my $entry = shift;
    my ($num, $repo, $name, $type) = @{$entry}{qw(_num repo name type)};
    if (not $name) {
        $error = "Can't $action $repo. No name.";
        return;
    }
    if (not $type) {
        $error = "Can't $action $name. Unknown type.";
        return;
    }
    if ($type ne 'git') {
        $error = "Can't $action $name. Type $type not yet supported.";
        return;
    }
    return 1;
}

sub git_update {
    my $self = shift;
    my $entry = shift;
    my ($repo, $name) = @{$entry}{qw(repo name)};
    if (not -d $name) {
        my $cmd = "git clone $repo $name";
        my ($o, $e) = capture { system($cmd) };
        if ($e =~ /\S/) {
            $quiet = 'Error';
            $verbose = "\n$o$e";
        }
        else {
            $normal = 'Done';
        }
    }
    elsif (-d "$name/.git") {
        my ($o, $e) = capture { system("cd $name; git pull") };
        if ($o eq "Already up-to-date.\n") {
            $normal = "Already up to date";
        }
        else {
            $quiet = "Updated";
            $verbose = "\n$o$e";
        }
    }
    else {
        $quiet = "Skipped";
    }
}

sub git_status {
    my $self = shift;
    my $entry = shift;
    my ($repo, $name) = @{$entry}{qw(repo name)};
    if (not -d $name) {
        $error = "No local repository";
    }
    elsif (-d "$name/.git") {
        my ($o, $e) = capture { system("cd $name; git status") };
        if ($o =~ /^nothing to commit/m and
            not $e
        ) {
            if ($o =~ /Your branch is ahead .* by (\d+) /) {
                $quiet = "Ahead by $1";
                $verbose = "\n$o$e";
            }
            else {
                $normal = "OK";
            }
        }
        else {
            $quiet = "Dirty";
            $verbose = "\n$o$e";
        }
    }
    else {
        $quiet= "Skipped";
    }
}

sub help {
    print STDOUT <<'...';
Usage:
    aycabtu [ options ] [ names ]
    
Options:
    --file=file         # aycabtu config file. Default: 'AYCABTU'

    [--update | --status | --list]   # Action. Default: 'update'
        update          # Checkout or update the selected repos
        status          # Get status info on the selected repos
        list            # List the selected repos

    --all               # Use all the repos in the config file
    --tags=tags         # Select repos matching all the tags
                        # Option can be used more than once

Names:

    A list of the names to to select. You can use multiple names and
    file globbing, like this:

        aycabtu --update foo-repo bar-*-repo

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

This is a very early release. Only a couple features are implemented,
and somewhat poorly.

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
