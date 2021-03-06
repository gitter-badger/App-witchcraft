package App::witchcraft::Command::Euscan;

use base qw(App::witchcraft::Command);
use warnings;
use strict;
use App::witchcraft::Utils;
use App::witchcraft::Utils qw(stage password_dialog uniq natural_order);
use App::witchcraft::Utils::Gentoo qw(test_ebuild bump);

use File::stat;
use File::Copy;
use Git::Sub qw(add commit push pull);
use Locale::TextDomain 'App-witchcraft';

=encoding utf-8

=head1 NAME

App::witchcraft::Command::Euscan - Euscan entropy repository packages

=head1 SYNOPSIS

  $ witchcraft euscan
  $ witchcraft e [-v|--verbose] [-q|--quiet] [-c|--check] [-u|--update] [-m|--manifest] [-f|--force] [-g|--git] [-i|--install] [-r git_repository] <repo>

=head1 DESCRIPTION

Euscan entropy repository packages.

=head1 ARGUMENTS

=over 4

=item C<-u|--update>

it saves new ebuilds in to the current git_repository.

=item C<-f|--force>

-m and -i will have effect also on ebuilds that are marked as "to update" but already are in the repository.
This is useful when you want to re-ebuild all the new found.

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
        "r|root=s"   => "root",
        "m|manifest" => "manifest",
        "i|install"  => "install",
        "f|force"    => "force",
        "g|git"      => "git"
    );
}

sub run {
    my $self = shift;
    my $Repo = shift
        // App::witchcraft->instance->Config->param('OVERLAY_NAME');
    info __x( 'Euscan of the repository {repo}', repo => $Repo );
    my $password = password_dialog();
    info __ "Retrevieng packages in the repository" if $self->{verbose};
    my @Packages = uniq(`equo query list available $Repo -q`);
    chomp(@Packages);
    my @Updates;
    my @Added;
    my $c = 1;
    info __x( "Starting Euscan of {packages}", packages => "@Packages" )
        if $self->{verbose};
    my $dir
        = $self->{root}
        // App::witchcraft->instance->Config->param('GIT_REPOSITORY');
    chdir($dir);

    foreach my $Package (@Packages) {
        draw_up_line;
        notice "[$c/" . scalar(@Packages) . "] " . $Package;
        my @temp = `euscan -q -C $Package`;
        chomp(@temp);
        if ( !$self->{quiet} ) {
            info "** " . $_ for @temp;
        }
        push( @Updates, @temp );
        push( @Added, $self->update( $Package, $password, @temp ) )
            if ( @temp > 0 );
        $c++;
    }
    if ( @Updates > 0 ) {
        print $_ . "\n" for @Updates;
    }
    if ( $self->{git} and @Added > 0 ) {
        if ( emerge( { '-n' => "" }, @Added ) ) {
            send_report( __ "Euscan: These packages where correctly emerged",
                @Added );
        }
        else { send_report( __("Euscan: Error emerging"), @Added ) }
    }
}

sub update {
    my $self     = shift;
    my $Package  = shift;
    my $password = shift;

    my @temp = @_;
    return () if ( !$self->{update} and !$self->{check} );
    my $dir
        = $self->{root}
        // App::witchcraft->instance->Config->param('GIT_REPOSITORY');
    chdir($dir);
    error __ 'No GIT_REPOSITORY defined, or --root given' and exit 1
        if ( !$dir );
    my $atom = join( '/', $dir, $Package );
    info __x( "repository doesn't have that atom ({atom})", atom => $atom )
        and draw_down_line
        and return ()
        if ( !-d $atom );
    my $pack = shift @{ natural_order(@temp) };
    $pack =~ s/.*?\/(.*?)\:.*/$1/g;    #my ebuild name
    my $updated = join( '/', $atom, $pack . '.ebuild' );
    info __x( "Searching for {pack}", pack => $pack );

    if ( !-f $updated ) {
        draw_down_line
            and return ()
            if ( $self->{check} );
        bump( $atom, $updated );
    }
    else {
        info __x( "Update to {package} already exists", package => $Package );
        draw_down_line;
        return () if ( !$self->{force} );
    }
    draw_down_line
        and return ()
        if ( !$self->{manifest} );
    my $Test = $updated;
    $Test =~ s/$dir\/?//g;
    if (test_ebuild( $Test, $self->{manifest}, $self->{install}, $password ) )
    {
        stage($Package) if ( $self->{git} );
    }
    else {
        return ();
    }
    draw_down_line;

    #  return join( "/", $Package, $pack );
    return $Package;
}

1;
