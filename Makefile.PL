
use strict;
use warnings;

use 5.005;

use ExtUtils::MakeMaker 6.30;



my %WriteMakefileArgs = (
  "ABSTRACT" => "A more casual approach to creating and sending Email:: emails",
  "AUTHOR" => "Adam Kennedy <adamk\@cpan.org>, Ricardo SIGNES <rjbs\@cpan.org>",
  "BUILD_REQUIRES" => {},
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => "6.30"
  },
  "DISTNAME" => "Email-Stuffer",
  "EXE_FILES" => [],
  "LICENSE" => "perl",
  "NAME" => "Email::Stuffer",
  "PREREQ_PM" => {
    "Carp" => 0,
    "Email::MIME" => 0,
    "Email::MIME::Creator" => 0,
    "Email::Sender::Simple" => 0,
    "File::Basename" => 0,
    "File::Type" => 0,
    "Params::Util" => 0,
    "prefork" => 0,
    "strict" => 0,
    "warnings" => 0
  },
  "TEST_REQUIRES" => {
    "Email::Sender::Transport::Test" => 0,
    "File::Find" => 0,
    "File::Spec::Functions" => 0,
    "File::Temp" => 0,
    "Moo" => 0,
    "Test::More" => "0.96"
  },
  "VERSION" => "0.003",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


unless ( eval { ExtUtils::MakeMaker->VERSION(6.63_03) } ) {
  my $tr = delete $WriteMakefileArgs{TEST_REQUIRES};
  my $br = $WriteMakefileArgs{BUILD_REQUIRES};
  for my $mod ( keys %$tr ) {
    if ( exists $br->{$mod} ) {
      $br->{$mod} = $tr->{$mod} if $tr->{$mod} > $br->{$mod};
    }
    else {
      $br->{$mod} = $tr->{$mod};
    }
  }
}

unless ( eval { ExtUtils::MakeMaker->VERSION(6.56) } ) {
  my $br = delete $WriteMakefileArgs{BUILD_REQUIRES};
  my $pp = $WriteMakefileArgs{PREREQ_PM};
  for my $mod ( keys %$br ) {
    if ( exists $pp->{$mod} ) {
      $pp->{$mod} = $br->{$mod} if $br->{$mod} > $pp->{$mod};
    }
    else {
      $pp->{$mod} = $br->{$mod};
    }
  }
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

WriteMakefile(%WriteMakefileArgs);



