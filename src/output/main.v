module output

import term

pub fn log_ok(msg string) {
	println(term.green(term.bold('OK${term.white(": ${msg}")}')))
}

pub fn log_info(msg string) {
	println(term.blue(term.bold('INFO${term.white(": ${msg}")}')))
}

pub fn log_err(msg string) {
	println(term.red(term.bold('ERROR${term.white(": ${msg}")}')))
}

pub fn print_usage() {
	println('Usage: udlaunch [OPTIONS]...\n')
	println('  -h, --help         display this help info')
	println('  -u, --use NAME     use a specific table from configuration by name')
	println('  -c, --config PATH  override config file path')
	println('  -v, --verbose      show output of processes being run')
	println('  -V, --version      display version info\n')
}

pub fn print_version(version string) {
	println('${term.bold(term.green('udlaunch'))}: v${term.bold(term.blue('${version}'))}\n')
}
