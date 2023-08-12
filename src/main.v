module main

import os
import term
import toml
import cli { Command, Flag }



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
    mut cmd := Command
    {
        name: 'udlaunch'
        description: 'Userspace daemon launcher'
        version: '1.0.0'
        disable_help: true
        disable_version: true
        disable_man: true
        execute: metafunction
        posix_mode: true
    }

    cmd.add_flag(Flag{
        flag: .bool
        required: false
        name: 'help'
        abbrev: 'h'
        description: 'Print this help info'
    })


    cmd.add_flag(Flag{
        flag: .string
        required: false
        name: 'use'
        abbrev: 'u'
        description: "Pass a configuration set to use by it's name"
    })

    cmd.add_flag(Flag{
        flag: .bool
        required: false
        name: 'show-output'
        abbrev: 's'
        description: "Force UDLaunch to show the output of all processes, useful for debugging"
    })

    cmd.add_flag(Flag{
        flag: .string
        required: false
        name: 'config'
        abbrev: 'c'
        description: "Specify a configuration file path"
    })

    cmd.add_flag(Flag{
        flag: .bool
        required: false
        name: 'version'
        abbrev: 'v'
        description: "Display version information"
    })

    cmd.setup()
    cmd.parse(os.args)


}

fn metafunction(cmd Command) !
{
    mut flag_help := cmd.flags.get_bool('help')!
    mut flag_version := cmd.flags.get_bool('version')!
    mut flag_output := cmd.flags.get_bool('show-output')!
    mut flag_use := cmd.flags.get_string('use')!
    mut flag_config := cmd.flags.get_string('config')!

    if flag_use.starts_with('-') == true
    {
        log_err('-u/--use flag cannot start with a hypen (-) !')
        exit(1)
    }

    if flag_help == true
    {
        print_usage()
        exit(0)
    }

    if flag_version == true
    {
        print_version()
        exit(0)
    }

    if flag_config.len > 0
    {

        if flag_output == true
        {
            if flag_use.len > 0
            {
                entry_point(flag_config, flag_use, false)
            }

            else
            {
                entry_point(flag_config, '', false)
            }
        }

        else if flag_use.len > 0
        {
            entry_point(flag_config, flag_use, true)
        }

        else
        {
            entry_point(flag_config, '', true)
        }


    }

    else if flag_output == true
    {

        mut home_files := get_home_files()

        if flag_use.len > 0
        {
            entry_point(home_files[1], flag_use, false)
        }

        else
        {
            entry_point(home_files[1], '', false)
        }

    }

    else if flag_use.len > 0
    {
        mut home_files := get_home_files()
        entry_point(home_files[1], flag_use, true)
    }

    else
    {
        mut home_files := get_home_files()
        entry_point(home_files[1], '', true)
    }



}

fn entry_point(path string, tbl string, redirect bool)
{

    if path.len > 0 {

        if os.exists(path) {
            mut udaemon_array := read_toml_config(path, tbl)

            for i in 0 .. udaemon_array.len
            {
                run_daemon(mut udaemon_array[i], redirect)
            }

            log_ok("processes launched successfully")

        }

        else
        {
            log_err("Couldn't find your configuration file '${path}' ")
        }

    }

    else if path.len == 0
    {
        mut conf := get_home_files()

        mut config_file := conf[1]

        if os.exists(config_file) == true
        {
            mut udaemon_array := read_toml_config(config_file, tbl)

            for index in 0 .. udaemon_array.len
            {
                run_daemon(mut udaemon_array[index], redirect)
            }

            log_ok("processes launched successfully")
        }

        else
        {
            log_err("Couldn't find your configuration file '${config_file}' ")
        }

    }

}

fn check_running(name string) bool
{
    if os.execute('pgrep ${name}').exit_code == 0 { return true } else { return false }
}

fn get_daemon_pids(daemon string) []string
{
    mut pgrep := os.execute('pgrep ${daemon}')

    if pgrep.exit_code != 0 { return [] }

    mut pids := pgrep.output.split('\n')
    pids.delete_last()
    return pids

}

fn run_daemon(mut daemon Daemon, redirect bool)
{

    mut daemon_process := os.new_process(daemon.abs_path)
    
    if redirect == true { daemon_process.set_redirect_stdio() }

    /* unset env vars */
    if daemon.unsetenvs.len > 0
    {
        proc_unsetenvs(mut daemon_process, daemon.unsetenvs)
    }

    // set env vars
    if daemon.setenvs.len > 0
    {
        proc_setenvs(mut daemon_process, daemon)
    }
    
    // append arguments
    if daemon.args.len > 0
    {
        proc_setargs(mut daemon_process, daemon.args)
    }
    
    // kill it
    if daemon.restart
    {
        kill_daemon(get_daemon_pids(daemon.name))
        log_info("found ${daemon.name} runnning, killing it")
    }

    // Check if it's running to skip or continue
    if check_running(daemon.name)
    {
        log_ok("${daemon.name} is already running")
        return
    }
    
    // finally after all that, run it
    daemon_process.run()
    log_info("launching ${term.italic(daemon.name)}")

    return

}

fn kill_daemon(pids []string)
{
    for i in 0 .. pids.len
    {
        os.execute('kill ${pids[i]}')
    }
}

fn read_toml_config(path string, tbl string) []Daemon
{

    mut parsed_config := toml.parse_file(path) or
    {
        panic('Could not find ${path}')
    }

    mut num_daemons := 0
    mut daemon_array := []Daemon {}

    if tbl.len > 0
    {
        num_daemons = parsed_config.value(tbl).array().len
        for i in 0 .. num_daemons
        {
            mut current_daemon := parsed_config.value(tbl).array()[i]
            mut this := Daemon {}

            this.name = current_daemon.value('name').string()

            if val := current_daemon.value_opt('restart')   { this.restart   = val.bool()                } else { this.restart   = false }
            if val := current_daemon.value_opt('args')      { this.args      = val.array().as_strings()  } else { this.args      = []    }
            if val := current_daemon.value_opt('setenvs')   { this.setenvs   = val.as_map().as_strings() } else { this.setenvs   = {}    }
            if val := current_daemon.value_opt('unsetenvs') { this.unsetenvs = val.array().as_strings()  } else { this.unsetenvs = []    }

            if val := current_daemon.value_opt('path') { this.abs_path = val.string() }
            else { this.abs_path = os.find_abs_path_of_executable(this.name) or { panic('$err') } }

            daemon_array << this

        }
    }

    else
    {
        num_daemons = parsed_config.to_any().array()[0].array().len
        for i in 0 .. num_daemons
        {

            mut current_daemon := parsed_config.to_any().array()[0].array()[i]
            mut this := Daemon {}

            this.name = current_daemon.value('name').string()

            if val := current_daemon.value_opt('restart')   { this.restart   = val.bool()                } else { this.restart   = false }
            if val := current_daemon.value_opt('args')      { this.args      = val.array().as_strings()  } else { this.args      = []    }
            if val := current_daemon.value_opt('setenvs')   { this.setenvs   = val.as_map().as_strings() } else { this.setenvs   = {}    }
            if val := current_daemon.value_opt('unsetenvs') { this.unsetenvs = val.array().as_strings()  } else { this.unsetenvs = []    }

            if val := current_daemon.value_opt('path') { this.abs_path = val.string() }
            else { this.abs_path = os.find_abs_path_of_executable(this.name) or { panic('$err') } }

            daemon_array << this

        }
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

    mut config_dir := '${xdg_home}/udlaunch'
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

fn proc_setenvs(mut proc os.Process, daemon Daemon) os.Process
{

    mut set_keys := daemon.setenvs.keys()
    mut set_vals := daemon.setenvs.values()
    
    // if the env was already manually set
    if proc.env_is_custom
    {
        for i in 0 .. daemon.setenvs.len
        {
            proc.env << '${set_keys[i]}=${set_vals[i]}'
        }
    }
    
    else
    {
        mut custom_env := u_env.clone()
        for i in 0 .. daemon.setenvs.len
        {
            custom_env[set_keys[i]] = set_vals[i]
        }
        proc.set_environment(custom_env)
    }

    return proc

}

fn log_ok(msg string)
{
    mut msg_white := term.white(msg)
    println( term.green( term.bold('UDLAUNCH: ${msg_white}') ) )
}

fn log_info(msg string)
{
    mut msg_white := term.white(msg)
    println( term.blue( term.bold('UDLAUNCH: ${msg_white}') ) )
}

fn log_err(msg string)
{
    mut msg_white := term.white(msg)
    println( term.red( term.bold('UDLAUNCH: ${msg_white}') ) )
}

fn print_usage()
{
    println('${term.bold(term.green("UDLaunch"))}: [flags..] [options..]\n')
    println('  --help         -h    display this help information')
    println('  --use          -u    pass a specific config set by name')
    println('  --config       -c    give a non-default config file path')
    println('  --show-output  -s    force output of processes to be shown\n')
}

fn print_version()
{
    println('${term.bold(term.green("UDLaunch"))}: v${term.bold(term.magenta("0.1.0"))}\n')
}