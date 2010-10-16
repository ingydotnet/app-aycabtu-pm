use inc::Module::Install;

name 'App-AYCABTU';
all_from 'lib/App/AYCABTU.pm';
readme_from;
manifest_skip;
version_check;
ack_xxx;
repository 'git://github.com/ingydotnet/app-aycabtu-pm.git';

use_gloom 'App::AYCABTU::OO';

requires 'Getopt::Long';
requires 'YAML::XS';
requires 'Capture::Tiny';

install_script 'bin/aycabtu';
# use_testml;

WriteAll;
