module main

import os
import toml
import term

struct Daemon
{
	mut: 
        name string
	    restart bool
	    args []string
	    abs_path string
        setenvs map[string]string
        unsetenvs []string
}

const u_env := os.environ()


fn main()
{

    mut conf := get_home_files()

    mut config_dir  := conf[0]
    mut config_file := conf[1]

    os.ensure_folder_is_writable(config_dir) or { errlog("Couldn't find your '${config_dir}' directory!") }

    if os.exists(config_file) == true
    {
        mut udaemon_array := read_toml_config(config_file)

        for index in 0 .. udaemon_array.len
        {
            run_daemon(mut udaemon_array[index])
        }
    
    }

    else
    {
        errlog("Couldn't find your configuration file '${config_file}' ")
    }

}

fn check_running(name string) bool
{
	if os.execute('pgrep ${name}').exit_code == 0 { return true } else { return false }
}

fn get_daemon_pids(daemon string) []string
{
    mut pgrep := os.execute('pgrep ${daemon}')

    match pgrep.exit_code
    {
        0
        {
            mut pids := pgrep.output.split('\n')
            pids.delete_last()
            return pids
        }

        else { return [] }
    }    
}

fn run_daemon(mut daemon Daemon)
{

	mut daemon_process := os.new_process(daemon.abs_path)
    
    daemon_process.set_redirect_stdio()
    
    // TODO allow for user to force stdio to be shown
    
    /* --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- */

    if daemon.unsetenvs.len > 0
    {
        proc_unsetenvs(mut daemon_process, daemon.unsetenvs)
    }
    
    /* --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- */
    
    if daemon.setenvs.len > 0
    {
        proc_setenvs(mut daemon_process, daemon)
    }
    
    /* --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- */
    
    if daemon.args.len > 0
    {
        proc_setargs(mut daemon_process, daemon.args)
    }
    
    /* --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- */
    
    if daemon.restart
    {
        kill_daemon(get_daemon_pids(daemon.name))
    }

    /* --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- */

    if check_running(daemon.name)
    {
        println(oklog("${daemon.name} is already running"))
        return
    }
    
    // finally after all that, run it
    daemon_process.run()
    return


}


fn kill_daemon(pids []string)
{
    for idx in 0 .. pids.len
    {
		os.execute('kill ${pids[idx]}')
	}
}

fn read_toml_config(path string) []Daemon
{
    mut parsed_config := toml.parse_file(path) or
    {
        panic('Could not find test.toml!')
    }

    mut num_daemons := parsed_config.to_any().array().len
    mut daemon_array := []Daemon {}
  
    for idx in 0 .. num_daemons
    {
        mut this := Daemon {}
        this.name      = parsed_config.to_any().array()[idx].value('name').string()
        this.restart   = parsed_config.to_any().array()[idx].value('restart').bool()
        this.args      = parsed_config.to_any().array()[idx].value('args').array().as_strings()
        this.setenvs   = parsed_config.to_any().array()[idx].value('setenvs').as_map().as_strings()
        this.unsetenvs = parsed_config.to_any().array()[idx].value('unsetenvs').array().as_strings()
        this.abs_path  = os.find_abs_path_of_executable(this.name) or { panic("Couldn't find the executable for ${this.name} in your PATH!") }
        daemon_array << this
    }

    return daemon_array

}


fn get_home_files() []string
{
    mut homedir := os.home_dir()
    mut xdg_home := ''
    mut test_confdir := os.config_dir() or { panic('Could not find XDG_CONFIG_HOME') }

    if test_confdir == '' { xdg_home = '${homedir}/.config' }
    else { xdg_home = os.config_dir() or { panic('Internal error finding configuration directory') } }

    mut config_dir  := '${xdg_home}/udlaunch'
    mut config_file := '${config_dir}/config.toml'

    return [config_dir, config_file]

}

fn proc_setargs(mut proc os.Process, args_to_set []string) os.Process
{
    proc.args = args_to_set
    return proc
}

fn proc_unsetenvs(mut proc os.Process, envs_to_unset []string) os.Process
{
 
    mut custom_env := u_env.clone()
    
    for i in 0 .. envs_to_unset.len
    {
        mut this := envs_to_unset[i]
        if custom_env[this] != '' { custom_env.delete(this) }
    }

    proc.set_environment(custom_env)
    
    return proc

}

fn proc_setenvs(mut proc os.Process, dmn Daemon) os.Process
{

    mut set_keys := dmn.setenvs.keys()
    mut set_vals := dmn.setenvs.values()
    
    // if the env was already manually set
    if proc.env_is_custom
    {
        for i in 0 .. dmn.setenvs.len
        {
            proc.env << '${set_keys[i]}=${set_vals[i]}'
        }
    }
    
    else
    {
        mut custom_env := u_env.clone()
        for i in 0 .. dmn.setenvs.len
        {
            custom_env[set_keys[i]] = set_vals[i]
        }
        proc.set_environment(custom_env)
    }

    return proc

}

fn errlog(err string) string
{
    return term.red(term.bold('UDLAUNCH: ${term.white(err)}'))
}

fn oklog (msg string) string
{
    return term.blue(term.bold('UDLAUNCH: ${term.white(msg)}'))
}