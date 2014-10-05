package App::witchcraft::Plugin::Qacheck;

use Deeme::Obj -base;
use App::witchcraft::Utils qw(info error send_report uniq atom log_command);
use Cwd;

sub register {
    my ( $self, $emitter ) = @_;
    $emitter->on(
        "after_test" => sub {
            my ( $witchcraft, $ebuild ) = @_;
            send_report(
                "Repoman output for $ebuild",
                "Repoman output for $ebuild",
                $self->repoman($ebuild)
            );
        }
    );
    $emitter->on(
        "after_emerge" => sub {
            my ( $witchcraft, @EBUILDS ) = @_;
            $emitter->emit( after_test => $_ ) for @EBUILDS;
        }
    );
}

sub repoman {
    shift;
    my $cwd = cwd;
    local $_ = shift;
    s/\:\:.*//g;
    atom;
    chdir( App::witchcraft->instance->Config->param('GIT_REPOSITORY') . "/"
            . $_ );
    my @repoman = qx/repoman scan/;
    chdir($cwd);
    return @repoman;
}
1;
