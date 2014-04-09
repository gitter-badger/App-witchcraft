requires 'App::CLI';
requires 'App::CLI::Command';
requires 'App::CLI::Command::Help';
requires 'Carp::Always';
requires 'Config::Tiny';
requires 'File::Path';
requires 'File::Xcopy';
requires 'Git::Sub';
requires 'Regexp::Common';
requires 'Term::ANSIColor';
requires 'Term::ReadKey';
requires 'Test::More';
requires 'perl', '5.008_005';

on configure => sub {
    requires 'Module::Build::Tiny', '0.034';
};
