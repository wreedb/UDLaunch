module main

import os
import toml
import term
import cli { Command, Flag }
import daemon { Daemon }
import output

// u_env hashmap of string -> string environment variables from the user
const u_env = os.environ()
const udlaunch_version := "0.1.1"

// Options used in metafunction to neatly gather cli options
struct Options
{
    mut:
        path  string
        table string
        verbose bool
}

fn main() {
    
    mut cmd := Command{
        name:        "udlaunch"
        description: "Userspace daemon launcher"
        version:     udlaunch_version
        execute:     metafunction
        posix_mode:  true
        defaults:    struct{
	        man:     false
	        help:    false
	        version: false
        }
    }
    
    cmd.add_flag(Flag{
	    flag:        .bool
	    required:    false
	    name:        'help'
	    abbrev:      'h'
    })

    cmd.add_flag(Flag{
	    flag:        .string
	    required:    false
	    name:        'use'
	    abbrev:      'u'
    })

    cmd.add_flag(Flag{
	    flag:        .bool
	    required:    false
	    name:        "verbose"
	    abbrev:      "v"
    })

    cmd.add_flag(Flag{
	    flag:        .string
	    required:    false
	    name:        "config"
	    abbrev:      "c"
    })

    cmd.add_flag(Flag{
	    flag:        .bool
	    required:    false
	    name:        "version"
	    abbrev:      "V"
    })
    
    cmd.setup()
	cmd.parse(os.args)
}

fn metafunction(cmd Command) !
{
	mut flag_help    := cmd.flags.get_bool('help')!
	mut flag_version := cmd.flags.get_bool('version')!
	mut flag_verbose := cmd.flags.get_bool('verbose')!
	mut flag_use     := cmd.flags.get_string('use')!
	mut flag_config  := cmd.flags.get_string('config')!

    
    mut options := Options{}

    // prevent '--use -name' from causing an error, warn and quit.
	if flag_use.starts_with('-') == true
    {
		output.log_err('-u/--use flag cannot start with a hypen (-) !')
		exit(1)
	}
    
    // print usage info
	if flag_help == true
    {
		output.print_usage()
		exit(0)
	}

    // print the version
	if flag_version == true {
		output.print_version(udlaunch_version)
		exit(0)
	}

    ///** NORMAL FLAG HANDLING **///
    // simple one, it will default to false if not given
    options.verbose = flag_verbose
    // no --config flag
    if flag_config.len == 0
    {   // default location
        options.path = get_config_file()
    }
    // --config path was given
    else
    {   // use the value the passed
        options.path = flag_config
    }
    
    // no --use flag 
    if flag_use.len == 0
    {   // empty string should cause default execution
        options.table = ""
    }
    // --use given
    else
    {   // use the value given
        options.table = flag_use
    }

    // pass the generated struct to entry_point
    entry_point(options)

}

fn get_config_file() string {
	mut xdg_home := os.config_dir() or {
		output.log_err('could not find your ~/.config directory!')
		exit(126)
	}

	mut config_file := '${xdg_home}/udlaunch/config.toml'

	return config_file
}

fn entry_point(options Options) {
    // options contains;
    // - path:  string = path to their config.toml
    // - table: string = the toml table to use
    // - verbose: bool = verbose output on/off
	
    if options.path.len > 0
    {
		if os.exists(options.path) {
			
            mut udaemon_array := read_toml_config(options.path, options.table)

			for i in 0 .. udaemon_array.len
            {
				run_daemon(mut udaemon_array[i], options.verbose)
			}

			output.log_ok('processes launched successfully')
		}
        
        else
        {
			output.log_err("Couldn't find your configuration file at '${options.path}'")
            exit(126)
		}
	
    }
    // options.path is SOMEHOW empty
    // this shouldn't happen
    else
    {
		mut config_file := get_config_file()
        
		if os.exists(config_file) == true
        {
			mut udaemon_array := read_toml_config(config_file, options.table)

			for index in 0 .. udaemon_array.len
            {
				run_daemon(mut udaemon_array[index], options.verbose)
			}

			output.log_ok('processes launched successfully')
		
        }
        // something is very wrong with the users environment variables...
        else
        {
			output.log_err("Couldn't find your configuration file '${config_file}' ")
		}
	}
}

fn check_running(name string) bool {
	// if pgrep gives code 0, that means it's running.
    if os.execute('pgrep ${name}').exit_code == 0
    { return true } else { return false }
}

fn get_daemon_pids(cdaemon string) []string {
	mut pgrep := os.execute('pgrep ${cdaemon}')

	if pgrep.exit_code != 0 {
		return []
	}

	mut pids := pgrep.output.split('\n')
	pids.delete_last()
	return pids
}

fn run_daemon(mut cdaemon Daemon, verbose bool) {
	mut daemon_process := os.new_process(cdaemon.abs_path)

	if verbose == false {
		daemon_process.set_redirect_stdio()
	}

	// unset env vars
	if cdaemon.unsetenvs.len > 0 {
		proc_unsetenvs(mut daemon_process, cdaemon.unsetenvs)
	}

	// set env vars
	if cdaemon.setenvs.len > 0 {
		proc_setenvs(mut daemon_process, cdaemon)
	}

	// append arguments
	if cdaemon.args.len > 0 {
		proc_setargs(mut daemon_process, cdaemon.args)
	}

	// kill it
	if cdaemon.restart {
		kill_daemon(get_daemon_pids(cdaemon.name))
		output.log_info('found ${cdaemon.name} runnning, killing it')
	}

	// Check if it's running to skip or continue
	if check_running(cdaemon.name) {
		output.log_ok('${cdaemon.name} is already running')
		return
	}

	// finally after all that, run it
	daemon_process.run()
	output.log_info('launching ${term.italic(cdaemon.name)}')

	return
}

fn kill_daemon(pids []string) {
	for i in 0 .. pids.len {
		os.execute('kill ${pids[i]}')
	}
}

fn read_toml_config(path string, tbl string) []Daemon {
	mut parsed_config := toml.parse_file(path) or { panic('Could not find ${path}') }

	mut num_daemons := 0
	mut daemon_array := []Daemon{}

	if tbl.len > 0 {
		num_daemons = parsed_config.value(tbl).array().len
		for i in 0 .. num_daemons {
			mut current_daemon := parsed_config.value(tbl).array()[i]
			mut this := Daemon{}

			this.name = current_daemon.value('name').string()

			if val := current_daemon.value_opt('restart') {
				this.restart = val.bool()
			} else {
				this.restart = false
			}
			if val := current_daemon.value_opt('args') {
				this.args = val.array().as_strings()
			} else {
				this.args = []
			}
			if val := current_daemon.value_opt('setenvs') {
				this.setenvs = val.as_map().as_strings()
			} else {
				this.setenvs = {}
			}
			if val := current_daemon.value_opt('unsetenvs') {
				this.unsetenvs = val.array().as_strings()
			} else {
				this.unsetenvs = []
			}

			if val := current_daemon.value_opt('path') {
				this.abs_path = val.string()
			} else {
				this.abs_path = os.find_abs_path_of_executable(this.name) or { panic('${err}') }
			}

			daemon_array << this
		}
	} else {
		num_daemons = parsed_config.to_any().array()[0].array().len
		for i in 0 .. num_daemons {
			
            mut current_daemon := parsed_config.to_any().array()[0].array()[i]
			mut this := Daemon{}

			this.name = current_daemon.value('name').string()

			if val := current_daemon.value_opt('restart')   { this.restart   = val.bool() }                else { this.restart = false }
			if val := current_daemon.value_opt('args')      { this.args      = val.array().as_strings() }  else { this.args = [] }
			if val := current_daemon.value_opt('setenvs')   { this.setenvs   = val.as_map().as_strings() } else { this.setenvs = {} }
			if val := current_daemon.value_opt('unsetenvs') { this.unsetenvs = val.array().as_strings() }  else { this.unsetenvs = [] }

			if val := current_daemon.value_opt('path') { this.abs_path = val.string() }
            else
            {

				this.abs_path = os.find_abs_path_of_executable(this.name) or {
                    output.log_err("Could not find path to executable ${this.name}")
                    exit(1)
                }
			
            }

			daemon_array << this
		}
	}

	return daemon_array
}

// proc_setargs receives a Process struct and an array of command
// line arguments to apply to it; returns the modified Process struct
fn proc_setargs(mut proc os.Process, args_to_set []string) os.Process {
	proc.args = args_to_set
	return proc
}

fn proc_unsetenvs(mut proc os.Process, envs_to_unset []string) os.Process {
	mut custom_env := u_env.clone()

	for i in 0 .. envs_to_unset.len
    {
		// 'this' is the env var currently being
        // operated on in the iteration
        mut this := envs_to_unset[i]

		if custom_env[this] != ""
        {   // unset the requested env var
			custom_env.delete(this)
		}
	}

	proc.set_environment(custom_env)

	return proc
}

fn proc_setenvs(mut proc os.Process, cdaemon Daemon) os.Process {
	mut set_keys := cdaemon.setenvs.keys()
	mut set_vals := cdaemon.setenvs.values()

	// env was already manually set
	if proc.env_is_custom
    {   
		for i in 0 .. cdaemon.setenvs.len
        {   // set the 'env' field of Process as needed
            proc.env << "${set_keys[i]}=${set_vals[i]}"
        }
	}
    // env was NOT set
    else
    {
		mut custom_env := u_env.clone()
		for i in 0 .. cdaemon.setenvs.len {
			custom_env[set_keys[i]] = set_vals[i]
		}
		proc.set_environment(custom_env)
	}

	return proc
}