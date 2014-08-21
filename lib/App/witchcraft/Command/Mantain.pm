package App::witchcraft::Command::Mantain;

use base qw(App::witchcraft::Command);
use Carp::Always;
use warnings;
use strict;
use App::witchcraft::Utils;
use App::witchcraft::Command::Align;
use App::witchcraft::Command::Sync;
use App::witchcraft::Command::Upgrade;
use App::witchcraft::Command::Conflict;

=encoding utf-8

=head1 NAME

App::witchcraft::Command::Mantain - Automatic mantainance command

=head1 SYNOPSIS

  $ witchcraft mantain

=head1 DESCRIPTION

Automatic mantainance command: it executes align, sync and upgrade, if you supply options like -a or -s you can combine them, if you don't give such options all are enabled by default.

=head1 ARGUMENTS

=over 4

=item C<-a|--align>

Enable git repository alignment (C<witchcraft align>)

=item C<-s|--sync>

Enable git repository sync (C<witchcraft sync -iuxg>)

=item C<-u|--upgrade>

Enable entropy repository upgrade (C<witchcraft upgrade>)

=item C<-c|--conflict>

remove conflict between repositories (C<witchcraft conflict>)

=item C<-q|--quit>

Shutdown computer on finish

=item C<-l|--loop>

Loops the maintenance mode

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

L<App::witchcraft>, L<App::witchcraft::Command::Euscan>

=cut

sub options {
    (   "a|align"    => "align",
        "s|sync"     => "sync",
        "u|upgrade"  => "upgrade",
        "c|conflict" => "conflict",
        "e|euscan"   => "euscan",
        "q|quit"     => "quit",
        "l|loop"     => "loop"
    );
}

sub run {
    error 'You must run it with root permissions' and exit 1 if $> != 0;
    my $self = shift;
    if ( $self->{'loop'} ) {
        while (1) {
            $self->launch();
        }
    }
    else {
        $self->launch();
    }

    system("shutdown -h now") if ( $self->{'quit'} );
}

sub launch {
    my $self = shift;
    if (    !$self->{'align'}
        and !$self->{'sync'}
        and !$self->{'upgrade'}
        and !$self->{'conflict'}
        and !$self->{'euscan'} )
    {
        $self->{'align'}    = 1;
        $self->{'sync'}     = 1;
        $self->{'conflict'} = 1;
        $self->{'euscan'}   = 1;
    }
    if ( $self->{'euscan'} ) {
        my $Euscan = App::witchcraft::Command::Euscan->new;
        $Euscan->{'manifest'} = 1;
        $Euscan->{'install'}  = 1;
        $Euscan->{'git'}      = 1;
        $Euscan->{'update'}   = 1;
        $Euscan->run();
    }
    if ( $self->{'align'} ) {
        my $Align = App::witchcraft::Command::Align->new;
        $Align->run();
    }
    if ( $self->{'sync'} ) {
        my $Sync = App::witchcraft::Command::Sync->new;
        $Sync->{'install'}         = 1;
        $Sync->{'update'}          = 1;
        $Sync->{'ignore-existing'} = 1;
        $Sync->{'git'}             = 1;
        $Sync->run();
    }
    if ( $self->{'upgrade'} ) {
        my $Upgrade = App::witchcraft::Command::Upgrade->new;
        $Upgrade->run();
    }
    if ( $self->{'conflict'} ) {
        my $Conflict = App::witchcraft::Command::Conflict->new;
        $Conflict->{'delete'} = 1;
        $Conflict->run();
    }
    system("eit cleanup --quick");

    #system("eit vacuum --quick");
}

1;

