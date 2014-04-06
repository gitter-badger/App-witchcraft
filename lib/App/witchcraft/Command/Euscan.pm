package App::witchcraft::Command::Euscan;

use base qw(App::witchcraft::Command);
use warnings;
use strict;
use App::witchcraft::Utils;
use File::stat;
use File::Copy;
use Git::Sub qw(add commit);
=encoding utf-8

=head1 NAME

App::witchcraft::Command::Euscan - Euscan entropy repository packages

=head1 SYNOPSIS

  $ witchcraft euscan
  $ witchcraft e [-v|--verbose] [-q|--quiet] [-c|--check] [-u|--update] [-m|--manifest] [-g|--git] [-i|--install] [-r git_repository] <repo>

=head1 DESCRIPTION

Euscan entropy repository packages.

=head1 ARGUMENTS

=over 4

=item C<-u|--update> 

it saves new ebuilds in to the current git_repository.

=item C<-i|--install> 

it runs C<ebuild <name> install> against the ebuild.

=item C<-c|--check> 

only performs scan of the new packages and return the list

=item C<-m|--manifest> 

it runs C<ebuild <name> manifest> against the ebuild

=item C<-g|--git> 

it add the ebuild into the git index of the repository and commit with the "added ${P}"

=item C<-r|--root <REPOSITORY_DIRECTORY>> 

provided perform the git changes on C<<REPOSITORY_DIRECTORY>>

=item C<--help>

it prints the POD help.

=back

=head1 AUTHOR

mudler E<lt>mudler@dark-lab.netE<gt>

=head1 COPYRIGHT

Copyright 2014- mudler

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO
L<App::witchcraft>, L<App::witchcraft::Command::Sync>

=cut

sub options {
    (   "v|verbose"  => "verbose",
        "q|quiet"    => "quiet",
        "c|check"    => "check",
        "u|update"   => "update",
        "r|root=s"     => "root",
        "m|manifest" => "manifest",
        "i|install"  => "install",
        "g|git"      => "git"
    );
}

sub run {
    my $self     = shift;
    my $Repo     = shift // "spike";
    my @Packages = `equo query list available $Repo -q`;
    chomp(@Packages);
    my @Updates;
    my @Added;
    my $c = 1;
    foreach my $Package (@Packages) {
        notice "[$c/" . scalar(@Packages) . "] " . $Package
            if $self->{verbose};
        my @temp = `euscan -q -C $Package`;
        chomp(@temp);
        if ( !$self->{quiet} ) {
            info "** \n" . $_, for @temp;
        }
        push( @Updates, @temp );
        push( @Added, $self->update( $Package, @temp ) ) if ( @temp > 0 );
        $c++;
    }
    info git::push;
    if ( @Updates > 0 ) {
        print $_ . "\n" for @Updates;
    }
    if ( $self->{git} ) {
        system("layman -S")
            && system( "emerge -av " . join( " ", @Added ) );
    }
}

sub update {
    my $self    = shift;
    my $Package = shift;
    my @temp    = @_;
    return undef if ( !$self->{update} and !$self->{check} );
    error "\n";
    error "|===================================================\\";
    my $dir
        = $self->{root} || -d "/home/" . $ENV{USER} . "/_git/gentoo-overlay"
        ? "/home/" . $ENV{USER} . "/_git/gentoo-overlay"
        : "/home/" . $ENV{USER} . "/git/gentoo-overlay";
    my $atom = join( '/', $dir, $Package );
    info '|| - repository doesn\'t have that atom (' . $atom . ')'
        and error "|===================================================/"
        and return undef
        if ( !-d $atom );
    notice '|| - opening ' . $atom;
    opendir( DH, $atom );
    my @files = grep {/\.ebuild$/}
        sort { -M join( '/', $atom, $a ) <=> -M join( '/', $atom, $b ) }
        grep { -f join( '/', $atom, $_ ) } readdir(DH);
    closedir(DH);

    my @Temp = @temp[    #natural sort order for strings containing numbers
        map { unpack "N", substr( $_, -4 ) }
        sort
        map {
            my $key = $temp[$_];
            $key =~ s[(\d+)][ pack "N", $1 ]ge;
            $key . pack "CNN", 0, 0, $_
        } 0 .. $#temp
    ];
    my $pack = shift @temp;

    $pack =~ s/.*?\/(.*?)\:.*/$1/g;
    my $updated = join( '/', $atom, $pack . '.ebuild' );
    info "|| - Searching for $pack";

    if ( !-f $updated ) {
        error "|===================================================/"
            and return undef
            if ( $self->{check} and -f $updated );
        my $last = shift @files;
        my $source = join( '/', $atom, $last );
        notice "|| - " . $last
            . ' was chosen to be the source of the new version';
        notice "|| - " . $updated . " updated"
            if defined $last and copy( $source, $updated );
    }
    else {
        info "|| - Update to $Package already exists";
    }
    error "|===================================================/"
        and return undef
        if ( !$self->{manifest} );
    if ( system("ebuild $updated manifest") == 0 ) {
        notice '|| - Manifest created successfully';
        error "|===================================================/"
            and return undef
            if ( !$self->{install} );
        if ( system("ebuild $updated install") == 0 ) {
            info '|| - Installation OK';
            chdir($atom);
            if ( $self->{git} ) {
                git::add './';
                info '|| - Added to git index of the repository';
                git::commit -m => 'added ' . $pack;
                info '|| - Committed with "' . 'added ' . $pack . "'";
            }
        }
    }
    error "||\n";
    error "|===================================================/";
    return join( "/", $Package, $pack );

}

1;
