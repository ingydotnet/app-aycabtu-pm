use inc::Module::Install;

name 'App-AYCABTU';
all_from 'lib/App/AYCABTU.pm';
readme_from;
manifest_skip;
version_check;
ack_xxx;

requires 'YAML::XS';

install_script 'bin/aycabtu';

WriteAll;
