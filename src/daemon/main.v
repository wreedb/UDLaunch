module daemon

pub struct Daemon {
pub mut:
	name      string
	restart   bool
	args      []string
	abs_path  string
	setenvs   map[string]string
	unsetenvs []string
}
